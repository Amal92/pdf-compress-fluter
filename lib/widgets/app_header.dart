import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/compression_controller.dart';
import '../screens/my_data_screen.dart';
import '../services/usage_quota_service.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final quota = Get.find<UsageQuotaService>();
    final compression = Get.find<CompressionController>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Compress',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'PDF',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Obx(() {
                  // Rx reads must happen inside this closure so GetX can subscribe.
                  final isUnlimited = quota.unlimited.value;
                  final isSubscribed = compression.isUserPro.value;
                  final used =
                      quota.usage.value?.totalPagesCompressed ?? 0;

                  if (isUnlimited || isSubscribed) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.successBorder),
                      ),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successText,
                        ),
                      ),
                    );
                  }

                  final remaining = (kFreeMaxCompressedPages - used)
                      .clamp(0, kFreeMaxCompressedPages);
                  final isNearLimit = remaining <= 5;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isNearLimit
                          ? AppColors.warningLight
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isNearLimit
                            ? AppColors.warningBorder
                            : AppColors.primaryBorder,
                      ),
                    ),
                    child: Text(
                      '$used / $kFreeMaxCompressedPages pages',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isNearLimit
                            ? AppColors.warningText
                            : AppColors.primary,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textSecondary,
                  ),
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onSelected: (value) {
                    if (value == 'my_data') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyDataScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'my_data',
                      child: Text('My Data'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
