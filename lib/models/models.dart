enum FileStatus {
  pending,
  uploading,
  uploaded,
  compressing,
  done,
  failed,
  quotaExceeded,
}

enum CompressionLevel { light, balanced, strong }

enum CompressionJobStatus { queued, processing, done, failed, aborted }

class CompressionSettings {
  final String type; // 'simple' | 'target'
  final CompressionLevel? level;
  final double? targetSizeMb;
  final double? targetDisplayValue;
  final String? targetDisplayUnit; // 'KB' | 'MB'

  const CompressionSettings({
    required this.type,
    this.level,
    this.targetSizeMb,
    this.targetDisplayValue,
    this.targetDisplayUnit,
  });
}

class FileState {
  final String id;
  final String fileName;
  final int fileSize;
  final String filePath;
  final FileStatus status;
  final int uploadProgress;
  final String? sessionId;
  final String? jobId;
  final CompressionJobStatus? compressionStatus;
  final CompressionSettings? compressionSettings;
  final int? originalSize;
  final int? compressedSize;
  final String? downloadUrl;
  final bool? targetReached;
  final String? error;

  const FileState({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    this.status = FileStatus.pending,
    this.uploadProgress = 0,
    this.sessionId,
    this.jobId,
    this.compressionStatus,
    this.compressionSettings,
    this.originalSize,
    this.compressedSize,
    this.downloadUrl,
    this.targetReached,
    this.error,
  });

  FileState copyWith({
    FileStatus? status,
    int? uploadProgress,
    String? sessionId,
    String? jobId,
    CompressionJobStatus? compressionStatus,
    CompressionSettings? compressionSettings,
    int? originalSize,
    int? compressedSize,
    String? downloadUrl,
    bool? targetReached,
    String? error,
  }) {
    return FileState(
      id: id,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      sessionId: sessionId ?? this.sessionId,
      jobId: jobId ?? this.jobId,
      compressionStatus: compressionStatus ?? this.compressionStatus,
      compressionSettings: compressionSettings ?? this.compressionSettings,
      originalSize: originalSize ?? this.originalSize,
      compressedSize: compressedSize ?? this.compressedSize,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      targetReached: targetReached ?? this.targetReached,
      error: error ?? this.error,
    );
  }
}

class UploadUrlResponse {
  final String sessionId;
  final String uploadUrl;
  final int maxSizeBytes;

  const UploadUrlResponse({
    required this.sessionId,
    required this.uploadUrl,
    required this.maxSizeBytes,
  });

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) =>
      UploadUrlResponse(
        sessionId: json['session_id'] as String,
        uploadUrl: json['upload_url'] as String,
        maxSizeBytes: json['max_size_bytes'] as int? ?? 0,
      );
}

class CompressJobResponse {
  final String sessionId;
  final String jobId;
  final String status;

  const CompressJobResponse({
    required this.sessionId,
    required this.jobId,
    required this.status,
  });

  factory CompressJobResponse.fromJson(Map<String, dynamic> json) =>
      CompressJobResponse(
        sessionId: json['session_id'] as String,
        jobId: json['job_id'] as String,
        status: json['status'] as String,
      );
}

class UsageResponse {
  /// Lifetime sum of page counts across successful compressions (see PRD).
  final int totalPagesCompressed;
  final int totalFilesCompressed;
  final bool unlimited;
  final int? pagesUsed;
  final int? pagesLimit;
  final int? pagesRemaining;
  final String? planName;

  const UsageResponse({
    required this.totalPagesCompressed,
    required this.totalFilesCompressed,
    required this.unlimited,
    this.pagesUsed,
    this.pagesLimit,
    this.pagesRemaining,
    this.planName,
  });

  factory UsageResponse.fromJson(Map<String, dynamic> json) => UsageResponse(
        totalPagesCompressed: json['total_pages_compressed'] as int? ?? 0,
        totalFilesCompressed: json['total_files_compressed'] as int? ?? 0,
        unlimited: json['unlimited'] as bool? ?? false,
        pagesUsed: json['pages_used'] as int?,
        pagesLimit: json['pages_limit'] as int?,
        pagesRemaining: json['pages_remaining'] as int?,
        planName: (json['plan'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class JobStatusResponse {
  final String jobId;
  final String status;
  final String sessionId;
  final String? downloadUrl;
  final int? originalSize;
  final int? compressedSize;
  final bool? targetReached;
  final String? error;

  const JobStatusResponse({
    required this.jobId,
    required this.status,
    required this.sessionId,
    this.downloadUrl,
    this.originalSize,
    this.compressedSize,
    this.targetReached,
    this.error,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) =>
      JobStatusResponse(
        jobId: json['job_id'] as String,
        status: json['status'] as String,
        sessionId: json['session_id'] as String,
        downloadUrl: json['download_url'] as String?,
        originalSize: json['original_size'] as int?,
        compressedSize: json['compressed_size'] as int?,
        targetReached: json['target_reached'] as bool?,
        error: json['error'] as String?,
      );
}
