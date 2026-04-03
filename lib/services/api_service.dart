import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../models/models.dart';
import 'token_storage.dart';

class ApiService extends GetxService {
  static const String _baseUrl = 'https://api.basastudios.com';

  late final Dio _dio;
  late final Dio _s3Dio;
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isRefreshing = false;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _s3Dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final token = await _tokenStorage.getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(opts);
              _isRefreshing = false;
              handler.resolve(response);
              return;
            }
          } catch (_) {}
          _isRefreshing = false;
        }
        handler.next(error);
      },
    ));

    // TODO: remove temporary API logging
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('[ApiService] $obj'),
    ));

    _s3Dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('[ApiService S3] ${options.method} ${options.uri}');
        debugPrint('[ApiService S3] headers: ${options.headers}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint(
            '[ApiService S3] ${response.statusCode} ${response.requestOptions.uri}');
        debugPrint('[ApiService S3] response headers: ${response.headers.map}');
        handler.next(response);
      },
      onError: (e, handler) {
        debugPrint('[ApiService S3] error: $e');
        if (e.response != null) {
          debugPrint(
              '[ApiService S3] error response: ${e.response?.statusCode} ${e.response?.headers.map}');
        }
        handler.next(e);
      },
    ));
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      // TODO: remove temporary refresh logging
      final refreshClient = Dio();
      refreshClient.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[ApiService refresh] $obj'),
      ));
      final response = await refreshClient.post(
        '$_baseUrl/pdf-compress/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );
      final newToken = response.data['access_token'] as String;
      await _tokenStorage.saveAccessToken(newToken);
      return true;
    } catch (_) {
      await _tokenStorage.clearAll();
      return false;
    }
  }

  // ── Auth ──

  /// Firebase Anonymous → backend JWTs. Refresh via [_tryRefreshToken] / `auth/refresh`.
  Future<Map<String, dynamic>> authenticate(String firebaseToken) async {
    final response =
        await _dio.post('/pdf-compress/auth/mobile/authenticate', data: {
      'firebase_token': firebaseToken,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Upload URL ──

  Future<UploadUrlResponse> getUploadUrl(String filename, {bool isUserPro = false}) async {
    final response =
        await _dio.post('/pdf-compress/mobile/upload-url', data: {
      'filename': filename,
      'isUserPro': isUserPro,
    });
    return UploadUrlResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── S3 Upload ──

  Future<void> uploadToS3(
    String uploadUrl,
    String filePath,
    void Function(int sent, int total) onProgress,
  ) async {
    final file = File(filePath);
    final fileLength = await file.length();
    await _s3Dio.put(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Length': fileLength,
        },
      ),
      onSendProgress: onProgress,
    );
  }

  // ── Compress ──

  Future<CompressJobResponse> compress({
    required String sessionId,
    required CompressionLevel level,
    bool isUserPro = false,
  }) async {
    final response = await _dio.post('/pdf-compress/mobile/compress', data: {
      'session_id': sessionId,
      'level': level.name,
      'isUserPro': isUserPro,
    });
    return CompressJobResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CompressJobResponse> compressToTarget({
    required String sessionId,
    required double targetSizeMb,
    bool isUserPro = false,
  }) async {
    final response =
        await _dio.post('/pdf-compress/mobile/compress-to-target', data: {
      'session_id': sessionId,
      'target_size_mb': targetSizeMb,
      'isUserPro': isUserPro,
    });
    return CompressJobResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Status ──

  Future<JobStatusResponse> getJobStatus(String jobId) async {
    final response = await _dio.get('/pdf-compress/status/$jobId');
    return JobStatusResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Abort ──

  Future<void> abortJob(String jobId) async {
    await _dio.post('/pdf-compress/jobs/$jobId/abort');
  }

  // ── Usage ──

  Future<UsageResponse> getUsage() async {
    final response = await _dio.get('/pdf-compress/usage');
    return UsageResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Active sessions (My Data) ──

  Future<ActiveSessionsResponse> getActiveSessions() async {
    final response = await _dio.get('/pdf-compress/sessions/active');
    return ActiveSessionsResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  // ── Delete session ──

  Future<void> deleteSession(String sessionId) async {
    await _dio.delete('/pdf-compress/session/$sessionId');
  }

  // ── Error helpers ──

  static String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      switch (error.response?.statusCode) {
        case 403:
          return data is Map && data['error'] != null
              ? data['error'].toString()
              : 'File size exceeds your plan limit.';
        case 429:
          return 'You\'re compressing too fast. Please wait a moment and try again.';
        case 503:
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'Network error. Please check your connection.';
      }
    }
    return error.toString();
  }

  static bool isQuotaExceeded(dynamic error) {
    if (error is DioException && error.response?.statusCode == 403) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        final msg = data['error'].toString().toLowerCase();
        return msg.contains('quota') ||
            msg.contains('limit') ||
            msg.contains('pages');
      }
    }
    return false;
  }
}
