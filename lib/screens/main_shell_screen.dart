import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/compression_controller.dart';
import '../widgets/app_header.dart';
import 'home_screen.dart';
import 'merge_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;

  Future<void> _onCompressMergedPdf(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    final compression = Get.find<CompressionController>();
    compression.addFile(
      filePath: path,
      fileName: 'merged.pdf',
      fileSize: bytes.length,
    );

    if (mounted) {
      setState(() => _tabIndex = 0);
    }
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
        ],
      ),
    );
  }
}
