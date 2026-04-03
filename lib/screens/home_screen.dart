import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/compression_controller.dart';
import '../widgets/app_header.dart';
import '../widgets/file_picker_area.dart';
import '../widgets/file_item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _onUpgradeSuccess() {
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final compression = Get.find<CompressionController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
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
                        TextSpan(text: ' size you want'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── File area ──────────────────────────────────────────────
                  Obx(() {
                    final files = compression.files;

                    if (files.isEmpty) {
                      return FilePickerArea(onUpgradeToPro: _onUpgradeSuccess);
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
                              onUpgradeToPro: _onUpgradeSuccess,
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

            // ── Confetti overlay ───────────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFEA580C),
                  Color(0xFFFBBF24),
                  Color(0xFF10B981),
                  Color(0xFF3B82F6),
                  Color(0xFFA855F7),
                ],
                numberOfParticles: 30,
                maxBlastForce: 40,
                minBlastForce: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

