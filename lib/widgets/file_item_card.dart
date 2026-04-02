import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../controllers/compression_controller.dart';
import '../models/models.dart';
import 'compression_options.dart';

class FileItemCard extends StatelessWidget {
  final FileState fileState;
  final CompressionController compression;

  const FileItemCard({
    super.key,
    required this.fileState,
    required this.compression,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Done state back / close row
          if (fileState.status == FileStatus.done) ...[
            _DoneTopRow(
              onBack: () => compression.resetFile(fileState.id),
              onClose: () => compression.deleteSession(fileState.id),
            ),
            const SizedBox(height: 8),
          ],

          // File header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileState.fileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSize(fileState.fileSize),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(fileState: fileState),
              if (fileState.status != FileStatus.compressing &&
                  fileState.status != FileStatus.done) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => compression.removeFile(fileState.id),
                  child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),

          // Upload progress bar
          if (fileState.status == FileStatus.uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fileState.uploadProgress / 100,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],

          // Error banner
          if (fileState.error != null &&
              (fileState.status == FileStatus.failed ||
                  fileState.status == FileStatus.quotaExceeded)) ...[
            const SizedBox(height: 10),
            _ErrorBanner(
              message: fileState.error!,
              showRetry: _isNetworkError(fileState.error) &&
                  fileState.status == FileStatus.failed,
              onRetry: () => compression.retryUpload(fileState.id),
            ),
          ],

          // Compression options (uploaded state)
          if (fileState.status == FileStatus.uploaded) ...[
            CompressionOptions(
              originalSize: fileState.originalSize ?? fileState.fileSize,
              isProcessing: false,
              onCompress: (type, settings) =>
                  compression.compressFile(fileState.id, type, settings),
            ),
          ],

          // Compressing indicator
          if (fileState.status == FileStatus.compressing) ...[
            const SizedBox(height: 12),
            _CompressingCard(fileState: fileState, compression: compression),
          ],

          // Done result
          if (fileState.status == FileStatus.done) ...[
            const SizedBox(height: 12),
            _DoneCard(fileState: fileState, compression: compression),
          ],
        ],
      ),
    );
  }

  bool _isNetworkError(String? msg) {
    if (msg == null) return false;
    final lower = msg.toLowerCase();
    return lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('connection');
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _DoneTopRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _DoneTopRow({required this.onBack, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Row(
            children: [
              Icon(Icons.chevron_left, size: 18, color: AppColors.textSecondary),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClose,
          child: const Row(
            children: [
              Text(
                'Close',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final FileState fileState;
  const _StatusBadge({required this.fileState});

  @override
  Widget build(BuildContext context) {
    final (label, bg, text) = switch (fileState.status) {
      FileStatus.pending => ('Pending', const Color(0xFFF1F5F9), AppColors.textSecondary),
      FileStatus.uploading => (
          'Uploading ${fileState.uploadProgress}%',
          const Color(0xFFDBEAFE),
          const Color(0xFF1D4ED8),
        ),
      FileStatus.uploaded => ('Ready', AppColors.successLight, AppColors.success),
      FileStatus.compressing => (
          fileState.compressionStatus == CompressionJobStatus.queued
              ? 'Queued'
              : 'Processing',
          const Color(0xFFFEF9C3),
          const Color(0xFF854D0E),
        ),
      FileStatus.done => ('Complete', AppColors.successLight, AppColors.success),
      FileStatus.failed => ('Failed', AppColors.errorLight, AppColors.error),
      FileStatus.quotaExceeded => (
          'Quota Exceeded',
          AppColors.errorLight,
          AppColors.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  const _ErrorBanner({
    required this.message,
    this.showRetry = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.errorText),
          ),
          if (showRetry && onRetry != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.errorText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompressingCard extends StatelessWidget {
  final FileState fileState;
  final CompressionController compression;

  const _CompressingCard({
    required this.fileState,
    required this.compression,
  });

  @override
  Widget build(BuildContext context) {
    final isTarget = fileState.compressionSettings?.type == 'target';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE047)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileState.compressionStatus == CompressionJobStatus.queued
                      ? 'Queued for compression…'
                      : 'Compressing your PDF…',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (fileState.compressionSettings != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    isTarget
                        ? 'Target: ${fileState.compressionSettings!.targetDisplayValue} ${fileState.compressionSettings!.targetDisplayUnit}'
                        : 'Level: ${fileState.compressionSettings!.level?.name ?? "balanced"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isTarget)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'This may take a moment while we find the best compression.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (isTarget)
            GestureDetector(
              onTap: () => compression.abortJob(fileState.id),
              child: const Text(
                'Abort',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  final FileState fileState;
  final CompressionController compression;

  const _DoneCard({required this.fileState, required this.compression});

  @override
  Widget build(BuildContext context) {
    final ratio = _compressionRatio();
    return Column(
      children: [
        // Success info panel
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.successBorder),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Compression complete!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successText,
                    ),
                  ),
                ],
              ),
              if (fileState.originalSize != null &&
                  fileState.compressedSize != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_formatSize(fileState.originalSize!)} → ${_formatSize(fileState.compressedSize!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (ratio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved $ratio% of space',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // Target not reached warning
        if (fileState.targetReached == false &&
            fileState.compressedSize != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amberBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Couldn't compress below your target. Best achieved: ${_formatSize(fileState.compressedSize!)}.",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.amberText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => compression.downloadFile(fileState.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Download',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => compression.deleteSession(fileState.id),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _compressionRatio() {
    final orig = fileState.originalSize;
    final comp = fileState.compressedSize;
    if (orig == null || comp == null || orig == 0) return null;
    final ratio = ((orig - comp) / orig * 100);
    return ratio.toStringAsFixed(1);
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }
}
