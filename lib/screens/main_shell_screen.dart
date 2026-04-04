import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_colors.dart';
import '../controllers/compression_controller.dart';
import '../services/usage_quota_service.dart';
import '../widgets/PayWall/PaywallDialog.dart';
import '../widgets/app_header.dart';
import '../widgets/file_picker_area.dart';
import 'home_screen.dart';
import 'merge_screen.dart';
import 'split_screen.dart';

const int _proPlanMaxPdfMb = 50;

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;

  Future<void> _onCompressMergedPdf(Uint8List bytes) async {
    final compression = Get.find<CompressionController>();
    final ctx = Get.context;

    if (compression.quotaExceeded.value && !compression.isUserPro.value) {
      if (ctx != null && ctx.mounted) {
        await _showQuotaExceededDialog(ctx, compression);
      }
      return;
    }

    const freeMaxMb = 10;
    final maxMb = compression.isUserPro.value ? _proPlanMaxPdfMb : freeMaxMb;
    final maxBytes = maxMb * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (ctx != null && ctx.mounted) {
        await showFileTooLargeDialog(ctx, fileName: 'merged.pdf', maxMb: maxMb);
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    compression.addFile(
      filePath: path,
      fileName: 'merged.pdf',
      fileSize: bytes.length,
    );

    if (mounted) {
      setState(() => _tabIndex = 0);
    }
  }

  Future<void> _showQuotaExceededDialog(
    BuildContext context,
    CompressionController compression,
  ) async {
    final quota = Get.find<UsageQuotaService>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Free limit reached',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          "You've compressed ${quota.pagesCompressedTotal} of $kFreeMaxCompressedPages "
          'free pages. Upgrade to Pro for unlimited compressions.',
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await Get.to(
                () => PaywallDialog(fromOnboarding: false),
                fullscreenDialog: true,
              );
              if (result == 'success') {
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const AppHeader(),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const CompressHomeTab(),
          MergeScreen(onCompressMerged: _onCompressMergedPdf),
          SplitScreen(onCompressPdf: _onCompressMergedPdf),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf),
            label: 'Compress',
          ),
          NavigationDestination(
            icon: Icon(Icons.merge_type_outlined),
            selectedIcon: Icon(Icons.merge_type),
            label: 'Merge',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_split_outlined),
            selectedIcon: Icon(Icons.call_split),
            label: 'Split',
          ),
        ],
      ),
    );
  }
}
