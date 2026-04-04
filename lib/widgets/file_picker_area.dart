import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compression_controller.dart';
import '../services/usage_quota_service.dart';
import 'PayWall/PaywallDialog.dart';

const int _freePlanMaxMb = 10;
const int _proPlanMaxMb = 50;

class FilePickerArea extends StatelessWidget {
  const FilePickerArea({super.key, this.onUpgradeToPro});

  final VoidCallback? onUpgradeToPro;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final compression = Get.find<CompressionController>();

    return Obx(() {
      final isReady = auth.isAuthenticated.value;
      final isPro = compression.isUserPro.value;
      final quotaExceeded = compression.quotaExceeded.value;
      final quotaBlocksFreeUser = quotaExceeded && !isPro;
      final canPick = isReady && !quotaBlocksFreeUser;
      final maxMb = isPro ? _proPlanMaxMb : _freePlanMaxMb;

      return Column(
        children: [
          if (quotaBlocksFreeUser) ...[
            _QuotaBanner(onUpgradeToPro: onUpgradeToPro),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: canPick ? () => _pickFile(context, maxMb: maxMb) : null,
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
                    child: !isReady
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            quotaBlocksFreeUser
                                ? Icons.lock_outline_rounded
                                : Icons.upload_file_rounded,
                            size: 32,
                            color: quotaBlocksFreeUser
                                ? AppColors.textTertiary
                                : AppColors.primary,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    !isReady
                        ? 'Initializing…'
                        : quotaBlocksFreeUser
                            ? 'File picker disabled — free limit reached'
                            : 'Tap to select a PDF file',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: quotaBlocksFreeUser
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
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
                        TextSpan(
                          text: '${maxMb}MB',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: isPro
                              ? ' · Pro plan'
                              : ' · Upgrade for 50MB & multiple files',
                          style: const TextStyle(color: AppColors.textTertiary),
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

  Future<void> _pickFile(BuildContext context, {required int maxMb}) async {
    final compression = Get.find<CompressionController>();
    final maxBytes = maxMb * 1024 * 1024;

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
        if (!context.mounted) return;
        await showFileTooLargeDialog(
          context,
          fileName: picked.name,
          maxMb: maxMb,
          onUpgradeToPro: onUpgradeToPro,
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

Future<void> showFileTooLargeDialog(
  BuildContext context, {
  required String fileName,
  int maxMb = _freePlanMaxMb,
  VoidCallback? onUpgradeToPro,
}) async {
  final compression = Get.find<CompressionController>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'File Too Large',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$fileName exceeds the ${maxMb}MB limit.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const PaywallProBenefitsList(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final result = await Get.to(
                    () => PaywallDialog(fromOnboarding: false),
                    fullscreenDialog: true,
                  );
                  if (result == 'success') {
                    onUpgradeToPro?.call();
                    await compression.refreshSubscriptionStatus();
                  }
                },
                icon: SvgPicture.asset(
                  'assets/svg/crown.svg',
                  width: 18,
                  height: 18,
                ),
                label: const Text(
                  'Upgrade to Pro',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({this.onUpgradeToPro});

  final VoidCallback? onUpgradeToPro;

  Future<void> _openPaywall() async {
    final compression = Get.find<CompressionController>();
    final result = await Get.to(
      () => PaywallDialog(fromOnboarding: false),
      fullscreenDialog: true,
    );
    if (result == 'success') {
      onUpgradeToPro?.call();
      await compression.refreshSubscriptionStatus();
    }
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
                  'free pages. Upgrade to Pro for unlimited compressions.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.errorText,
                  ),
                )),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openPaywall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/crown.svg',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Upgrade to Pro',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
