import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/usage_quota_service.dart';
import '../utils/utils.dart';

class CompressionController extends GetxController {
  final _api = Get.find<ApiService>();
  late final UsageQuotaService _quotaService;

  final RxList<FileState> files = <FileState>[].obs;
  final RxBool quotaExceeded = false.obs;
  final RxBool isUserPro = false.obs;

  final Map<String, Timer> _pollingTimers = {};
  final _uuid = const Uuid();

  @override
  void onInit() {
    super.onInit();
    _quotaService = Get.find<UsageQuotaService>();
    quotaExceeded.value = _quotaService.quotaExceeded.value;
    ever(_quotaService.quotaExceeded, (bool val) => quotaExceeded.value = val);
    refreshSubscriptionStatus();
  }

  Future<void> refreshSubscriptionStatus() async {
    final status = await getSubscriptionStatus();
    if (status != null) {
      isUserPro.value = status;
    }
  }

  void addFile({
    required String filePath,
    required String fileName,
    required int fileSize,
  }) {
    final id = _uuid.v4();
    final fileState = FileState(
      id: id,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
    );
    files.add(fileState);
    _uploadFile(id);
  }

  void removeFile(String id) {
    _pollingTimers[id]?.cancel();
    _pollingTimers.remove(id);
    files.removeWhere((f) => f.id == id);
  }

  Future<void> _uploadFile(String id) async {
    _updateFile(id, (f) => f.copyWith(status: FileStatus.uploading));
    try {
      final fileState = _getFile(id);
      if (fileState == null) return;

      final uploadUrlRes =
          await _api.getUploadUrl(fileState.fileName, isUserPro: isUserPro.value);

      await _api.uploadToS3(
        uploadUrlRes.uploadUrl,
        fileState.filePath,
        (sent, total) {
          if (total > 0) {
            final progress = ((sent / total) * 100).round();
            _updateFile(id, (f) => f.copyWith(
                  status: FileStatus.uploading,
                  uploadProgress: progress,
                ));
          }
        },
      );

      _updateFile(
        id,
        (f) => f.copyWith(
          status: FileStatus.uploaded,
          sessionId: uploadUrlRes.sessionId,
          originalSize: fileState.fileSize,
        ),
      );
    } on DioException catch (e) {
      final msg = ApiService.extractErrorMessage(e);
      _updateFile(id, (f) => f.copyWith(status: FileStatus.failed, error: msg));
    } catch (e) {
      _updateFile(
          id, (f) => f.copyWith(status: FileStatus.failed, error: e.toString()));
    }
  }

  Future<void> compressFile(
    String id,
    String type,
    CompressionSettings settings,
  ) async {
    final fileState = _getFile(id);
    if (fileState == null || fileState.sessionId == null) return;

    _updateFile(
      id,
      (f) => f.copyWith(
        status: FileStatus.compressing,
        compressionStatus: CompressionJobStatus.queued,
        compressionSettings: settings,
      ),
    );

    try {
      CompressJobResponse jobRes;
      if (type == 'target') {
        jobRes = await _api.compressToTarget(
          sessionId: fileState.sessionId!,
          targetSizeMb: settings.targetSizeMb!,
          isUserPro: isUserPro.value,
        );
      } else {
        jobRes = await _api.compress(
          sessionId: fileState.sessionId!,
          level: settings.level ?? CompressionLevel.balanced,
          isUserPro: isUserPro.value,
        );
      }

      _updateFile(
        id,
        (f) => f.copyWith(
          jobId: jobRes.jobId,
          compressionStatus: CompressionJobStatus.queued,
        ),
      );

      _startPolling(id, jobRes.jobId);
    } on DioException catch (e) {
      if (ApiService.isQuotaExceeded(e)) {
        // Refresh usage for free users so UsageQuotaService drives quotaExceeded;
        // for unlimited users this is a server-side anomaly — don't block them.
        _quotaService.refreshIfFree();
        _updateFile(
          id,
          (f) => f.copyWith(
            status: _quotaService.unlimited.value
                ? FileStatus.failed
                : FileStatus.quotaExceeded,
            error: ApiService.extractErrorMessage(e),
          ),
        );
      } else {
        _updateFile(
          id,
          (f) => f.copyWith(
            status: FileStatus.failed,
            error: ApiService.extractErrorMessage(e),
          ),
        );
      }
    } catch (e) {
      _updateFile(
          id, (f) => f.copyWith(status: FileStatus.failed, error: e.toString()));
    }
  }

  void _startPolling(String fileId, String jobId) {
    _pollingTimers[fileId]?.cancel();
    _pollingTimers[fileId] = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(fileId, jobId),
    );
  }

  Future<void> _pollStatus(String fileId, String jobId) async {
    try {
      final status = await _api.getJobStatus(jobId);

      switch (status.status) {
        case 'queued':
          _updateFile(
              fileId,
              (f) =>
                  f.copyWith(compressionStatus: CompressionJobStatus.queued));
        case 'processing':
          _updateFile(
              fileId,
              (f) => f.copyWith(
                  compressionStatus: CompressionJobStatus.processing));
        case 'done':
          _pollingTimers[fileId]?.cancel();
          _pollingTimers.remove(fileId);
          _updateFile(
            fileId,
            (f) => f.copyWith(
              status: FileStatus.done,
              compressionStatus: CompressionJobStatus.done,
              downloadUrl: status.downloadUrl,
              originalSize: status.originalSize ?? f.originalSize,
              compressedSize: status.compressedSize,
              targetReached: status.targetReached,
            ),
          );
          _quotaService.refreshIfFree();
        case 'failed':
          _pollingTimers[fileId]?.cancel();
          _pollingTimers.remove(fileId);
          final errorMsg = status.error ?? 'Compression failed.';
          final isQuota = errorMsg.toLowerCase().contains('quota');
          if (isQuota) _quotaService.refreshIfFree();
          _updateFile(
            fileId,
            (f) => f.copyWith(
              status: (isQuota && !_quotaService.unlimited.value)
                  ? FileStatus.quotaExceeded
                  : FileStatus.failed,
              error: errorMsg,
            ),
          );
        case 'aborted':
          _pollingTimers[fileId]?.cancel();
          _pollingTimers.remove(fileId);
          _updateFile(
            fileId,
            (f) => f.copyWith(
                status: FileStatus.uploaded,
                jobId: null,
                compressionStatus: null,
                compressionSettings: null),
          );
      }
    } catch (_) {}
  }

  Future<void> abortJob(String fileId) async {
    final fileState = _getFile(fileId);
    if (fileState?.jobId == null) return;
    try {
      await _api.abortJob(fileState!.jobId!);
    } catch (_) {}
  }

  Future<void> deleteSession(String fileId) async {
    final fileState = _getFile(fileId);
    _pollingTimers[fileId]?.cancel();
    _pollingTimers.remove(fileId);
    if (fileState?.sessionId != null) {
      try {
        await _api.deleteSession(fileState!.sessionId!);
      } catch (_) {}
    }
    files.removeWhere((f) => f.id == fileId);
  }

  void resetFile(String fileId) {
    _pollingTimers[fileId]?.cancel();
    _pollingTimers.remove(fileId);
    _updateFile(
      fileId,
      (f) => FileState(
        id: f.id,
        fileName: f.fileName,
        fileSize: f.fileSize,
        filePath: f.filePath,
        status: FileStatus.uploaded,
        sessionId: f.sessionId,
        originalSize: f.originalSize,
      ),
    );
  }

  Future<void> downloadFile(String fileId) async {
    final fileState = _getFile(fileId);
    if (fileState?.downloadUrl == null) return;

    try {
      final dir = await getTemporaryDirectory();
      final savePath =
          '${dir.path}/${fileState!.fileName.replaceAll('.pdf', '')}_compressed.pdf';

      final dio = Dio();
      await dio.download(fileState.downloadUrl!, savePath);

      await OpenFilex.open(savePath);
    } catch (e) {
      Get.snackbar(
        'Download Failed',
        'Could not download the file. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void retryUpload(String fileId) {
    _updateFile(fileId, (f) => f.copyWith(status: FileStatus.pending, error: null));
    _uploadFile(fileId);
  }

  void _updateFile(String id, FileState Function(FileState) updater) {
    final index = files.indexWhere((f) => f.id == id);
    if (index == -1) return;
    files[index] = updater(files[index]);
  }

  FileState? _getFile(String id) {
    try {
      return files.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    super.onClose();
  }
}
