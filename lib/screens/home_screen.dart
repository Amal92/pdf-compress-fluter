import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/compression_controller.dart';
import '../widgets/app_header.dart';
import '../widgets/file_picker_area.dart';
import '../widgets/file_item_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compression = Get.find<CompressionController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Hero text ──────────────────────────────────────────────
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(text: 'Compress PDF to '),
                    TextSpan(
                      text: 'Any',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: ' size\nyou want'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Safe and supreme PDF compression',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // ── File area ──────────────────────────────────────────────
              Obx(() {
                final files = compression.files;

                if (files.isEmpty) {
                  return const FilePickerArea();
                }

                return Column(
                  children: [
                    ...files.map(
                      (fileState) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FileItemCard(
                          key: ValueKey(fileState.id),
                          fileState: fileState,
                          compression: compression,
                        ),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

