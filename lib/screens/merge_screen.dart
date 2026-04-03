import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../services/pdf_merge_service.dart';

class MergePdfItem {
  MergePdfItem({
    required this.id,
    required this.path,
    required this.displayName,
    required this.sizeBytes,
    this.pageCount = 0,
    this.loadingMeta = true,
  });

  final String id;
  final String path;
  final String displayName;
  final int sizeBytes;
  int pageCount;
  bool loadingMeta;
}

enum _MergePhase { idle, merging, done }

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, required this.onCompressMerged});

  final Future<void> Function(Uint8List bytes) onCompressMerged;

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final _uuid = const Uuid();
  final List<MergePdfItem> _items = [];
  final Set<String> _processingIds = {};
  _MergePhase _phase = _MergePhase.idle;
  String? _error;
  Uint8List? _mergedBytes;
  String? _mergedSizeMb;

  int get _totalPages =>
      _items.where((e) => !e.loadingMeta).fold(0, (a, e) => a + e.pageCount);

  Future<void> _pickMore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    await _ingestPlatformFiles(result.files);
  }

  Future<void> _ingestPlatformFiles(List<PlatformFile> picked) async {
    final paths = <String>[];
    for (final f in picked) {
      if (f.path != null && f.path!.isNotEmpty) {
        paths.add(f.path!);
      }
    }
    if (paths.isEmpty) return;

    setState(() {
      _phase = _MergePhase.idle;
      _error = null;
      _mergedBytes = null;
      _mergedSizeMb = null;
    });

    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final name = path.split(Platform.pathSeparator).last;
      if (!name.toLowerCase().endsWith('.pdf')) continue;

      final id = _uuid.v4();
      final displayName =
          name.toLowerCase().endsWith('.pdf') ? name.substring(0, name.length - 4) : name;
      final sizeBytes = await file.length();

      setState(() {
        _items.add(MergePdfItem(
          id: id,
          path: path,
          displayName: displayName,
          sizeBytes: sizeBytes,
        ));
        _processingIds.add(id);
      });

      try {
        final bytes = await file.readAsBytes();
        final count = PdfMergeService.countPages(bytes);
        if (!mounted) return;
        setState(() {
          final idx = _items.indexWhere((e) => e.id == id);
          if (idx >= 0) {
            _items[idx].pageCount = count;
            _items[idx].loadingMeta = false;
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          final idx = _items.indexWhere((e) => e.id == id);
          if (idx >= 0) {
            _items[idx].pageCount = 1;
            _items[idx].loadingMeta = false;
          }
        });
      } finally {
        if (mounted) {
          setState(() => _processingIds.remove(id));
        }
      }
    }
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
      _phase = _MergePhase.idle;
      _mergedBytes = null;
      _mergedSizeMb = null;
      _error = null;
    });
  }

  void _clearAll() {
    setState(() {
      _items.clear();
      _processingIds.clear();
      _phase = _MergePhase.idle;
      _mergedBytes = null;
      _mergedSizeMb = null;
      _error = null;
    });
  }

  Future<void> _merge() async {
    if (_items.length < 2) {
      setState(() {
        _error = 'Please add at least 2 PDF files to merge.';
      });
      return;
    }
    if (_items.any((e) => e.loadingMeta)) return;

    setState(() {
      _error = null;
      _phase = _MergePhase.merging;
    });

    try {
      final buffers = <Uint8List>[];
      for (final item in _items) {
        buffers.add(await File(item.path).readAsBytes());
      }
      final out = await PdfMergeService.mergeOrdered(buffers);
      final mb = (out.length / (1024 * 1024)).toStringAsFixed(2);
      if (!mounted) return;
      setState(() {
        _mergedBytes = out;
        _mergedSizeMb = mb;
        _phase = _MergePhase.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Failed to merge PDFs. One or more files may be encrypted or corrupt.';
        _phase = _MergePhase.idle;
      });
    }
  }

  Future<void> _openMerged() async {
    final bytes = _mergedBytes;
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(bytes, flush: true);
    await OpenFilex.open(path);
  }

  Future<void> _compressMerged() async {
    final bytes = _mergedBytes;
    if (bytes == null) return;
    await widget.onCompressMerged(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Merge PDF Files',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Combine multiple PDFs into one file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (_items.isEmpty) _buildEmptyDropzone() else _buildFileGrid(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(_error!),
            ],
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 20),
              if (_phase != _MergePhase.done) _buildMergeActions(),
              if (_phase == _MergePhase.done) _buildDoneCard(),
            ],
            const SizedBox(height: 36),
            _buildFeatureHighlights(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDropzone() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickMore,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drag & drop PDFs here',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'or tap to browse your files',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'You can select multiple files at once',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_items.length} ${_items.length == 1 ? 'file' : 'files'} added',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_totalPages > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$_totalPages total ${_totalPages == 1 ? 'page' : 'pages'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _clearAll,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
              label: Text(
                'Clear all',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final maxW = constraints.maxWidth;
            int crossAxisCount = (maxW / 120).floor().clamp(2, 5);
            if (maxW < 360) crossAxisCount = 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.72,
              ),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return _buildAddMoreCard();
                }
                final item = _items[index];
                return _buildFileCard(item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFileCard(MergePdfItem item) {
    final loading = _processingIds.contains(item.id) || item.loadingMeta;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: AppColors.panelBackground,
                  child: loading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Loading…',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.pageCount > 0
                          ? '${item.pageCount}p · ${_mb(item.sizeBytes)} MB'
                          : '${_mb(item.sizeBytes)} MB',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _removeItem(item.id),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoreCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickMore,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Add more files',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.errorText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeActions() {
    final busy = _phase == _MergePhase.merging;
    final canMerge = _items.length >= 2 &&
        !busy &&
        !_items.any((e) => e.loadingMeta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canMerge ? _merge : null,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.merge_type_rounded, size: 22),
          label: Text(busy ? 'Merging…' : 'Merge ${_items.length} PDFs'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.textTertiary.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_items.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Add at least 2 PDFs to merge',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDoneCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Merge complete!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_items.length} PDFs merged · $_totalPages pages · ${_mergedSizeMb ?? '—'} MB',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openMerged,
            icon: const Icon(Icons.download_rounded, size: 22),
            label: const Text('Open merged PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _compressMerged,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: const Text('Compress this PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _clearAll,
            child: Text(
              'Start over',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    const data = <({IconData icon, String title, String body})>[
      (
        icon: Icons.lock_outline_rounded,
        title: '100% Private',
        body:
            'Your PDFs stay on your device. Merging runs locally in the app.',
      ),
      (
        icon: Icons.bolt_outlined,
        title: 'Fast & Free',
        body: 'No account required. Combine PDFs in the order you add them.',
      ),
      (
        icon: Icons.high_quality_outlined,
        title: 'Original layout',
        body: 'Pages are composed from each file’s content in order.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < data.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _FeatureTile(
            icon: data[i].icon,
            title: data[i].title,
            body: data[i].body,
          ),
        ],
      ],
    );
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
