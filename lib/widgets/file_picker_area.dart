import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compression_controller.dart';
import '../services/usage_quota_service.dart';

const int _freePlanMaxMb = 10;

class FilePickerArea extends StatelessWidget {
  const FilePickerArea({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final compression = Get.find<CompressionController>();

    return Obx(() {
      final isReady = auth.isAuthenticated.value;
      final quotaExceeded = compression.quotaExceeded.value;

      return Column(
        children: [
          if (quotaExceeded) ...[
            const _QuotaBanner(),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: isReady ? () => _pickFile(context) : null,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBorder,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isReady
                        ? const Icon(
                            Icons.upload_file_rounded,
                            size: 32,
                            color: AppColors.primary,
                          )
                        : const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isReady ? 'Tap to select a PDF file' : 'Initializing…',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Maximum file size: '),
                        const TextSpan(
                          text: '${_freePlanMaxMb}MB',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(
                          text: ' · Upgrade for 50MB & multiple files',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _pickFile(BuildContext context) async {
    final compression = Get.find<CompressionController>();
    const maxBytes = _freePlanMaxMb * 1024 * 1024;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      if (picked.path == null) return;

      final file = File(picked.path!);
      final size = await file.length();

      if (size > maxBytes) {
        Get.snackbar(
          'File Too Large',
          '${picked.name} exceeds the ${_freePlanMaxMb}MB limit.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.errorLight,
          colorText: AppColors.errorText,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      compression.addFile(
        filePath: picked.path!,
        fileName: picked.name,
        fileSize: size,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not open file picker. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner();

  void _showUpgradeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Upgrade to Premium',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Get unlimited PDF compressions, larger file sizes (up to 50 MB), '
          'and priority processing.\n\nUpgrade once — compress forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quota = Get.find<UsageQuotaService>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free limit reached',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorText,
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() => Text(
                  "You've compressed ${quota.pagesCompressedTotal} of $kFreeMaxCompressedPages "
                  'free pages. Upgrade to Premium for unlimited compressions.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.errorText,
                  ),
                )),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showUpgradeDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
