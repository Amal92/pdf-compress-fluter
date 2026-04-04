import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
// ignore: implementation_imports — [PdfTexture] is not exported from package:pdfx.
import 'package:pdfx/src/viewer/wrappers/pdf_texture.dart';
import 'package:synchronized/synchronized.dart';

import '../constants/app_colors.dart';
import '../services/pdf_merge_service.dart';
import '../services/pdf_split_service.dart';

class _PageThumb {
  _PageThumb({required this.pageIndexZero, required this.displayNumber});

  final int pageIndexZero;
  final int displayNumber;
  bool selected = true;
}

enum _SplitPhase { idle, working, done }

class _SplitResult {
  _SplitResult({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// Split / extract pages or merge a selection — mirrors the website `/split` flow.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key, required this.onCompressPdf});

  final Future<void> Function(Uint8List bytes) onCompressPdf;

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

/// One page preview using pdfx **textures** ([PdfPage.createTexture]), same path as [PdfViewPinch].
class SplitPdfTextureTile extends StatefulWidget {
  const SplitPdfTextureTile({
    super.key,
    required this.document,
    required this.pageNumber,
  });

  final PdfDocument document;
  final int pageNumber;

  @override
  State<SplitPdfTextureTile> createState() => _SplitPdfTextureTileState();
}

class _SplitPdfTextureTileState extends State<SplitPdfTextureTile> {
  static final Lock _renderLock = Lock();

  PdfPage? _page;
  PdfPageTexture? _texture;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTexture());
  }

  Future<void> _loadTexture() async {
    await _renderLock.synchronized(() async {
      if (!mounted || widget.document.isClosed) return;
      PdfPage? page;
      PdfPageTexture? texture;
      try {
        page = await widget.document.getPage(
          widget.pageNumber,
          autoCloseAndroid: false,
        );
        final fw = page.width;
        final fh = page.height;
        if (!fw.isFinite || !fh.isFinite || fw <= 0 || fh <= 0) {
          await page.close();
          if (mounted) setState(() => _failed = true);
          return;
        }

        texture = await page.createTexture();
        const maxThumbW = 360.0;
        final scale = maxThumbW / fw;
        final tw = (fw * scale).round().clamp(72, 1600);
        final th = (fh * scale).round().clamp(72, 2800);

        await texture.updateRect(
          documentId: widget.document.id,
          width: tw,
          height: th,
          textureWidth: tw,
          textureHeight: th,
          fullWidth: fw,
          fullHeight: fh,
          backgroundColor: '#ffffff',
          allowAntiAliasing: true,
        );

        if (!mounted) {
          await texture.dispose();
          await page.close();
          return;
        }
        setState(() {
          _page = page;
          _texture = texture;
          page = null;
          texture = null;
        });
      } catch (_) {
        final t = texture;
        final pg = page;
        if (t != null) {
          await t.dispose();
        }
        if (pg != null && !pg.isClosed) {
          await pg.close();
        }
        if (mounted) setState(() => _failed = true);
      }
    });
  }

  @override
  void dispose() {
    final texture = _texture;
    final page = _page;
    _texture = null;
    _page = null;
    if (texture != null || page != null) {
      unawaited(
        _renderLock.synchronized(() async {
          try {
            await texture?.dispose();
          } catch (_) {}
          try {
            if (page != null && !page.isClosed) await page.close();
          } catch (_) {}
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(
          Icons.picture_as_pdf_outlined,
          size: 40,
          color: AppColors.textTertiary,
        ),
      );
    }
    final tex = _texture;
    if (tex == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    final tw = tex.textureWidth ?? 1;
    final th = tex.textureHeight ?? 1;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: tw.toDouble(),
        height: th.toDouble(),
        child: PdfTexture(textureId: tex.id),
      ),
    );
  }
}

class _SplitScreenState extends State<SplitScreen> {
  Uint8List? _pdfBytes;
  PdfDocument? _previewDoc;
  String _fileName = '';
  String _baseName = 'document';
  final List<_PageThumb> _pages = [];
  bool _loadingThumbs = false;
  bool _mergeSelected = false;
  _SplitPhase _phase = _SplitPhase.idle;
  List<_SplitResult> _results = [];
  String? _error;

  @override
  void dispose() {
    unawaited(_previewDoc?.close());
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || !mounted) return;
    final f = result.files.single;
    var name = f.name;
    Uint8List? bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      final path = f.path;
      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;
      bytes = await file.readAsBytes();
      name = path.split(Platform.pathSeparator).last;
    }
    if (!name.toLowerCase().endsWith('.pdf')) {
      setState(() => _error = 'Please choose a PDF file.');
      return;
    }
    await _loadPdf(bytes, name);
  }

  Future<void> _loadPdf(Uint8List bytes, String name) async {
    await _previewDoc?.close();
    _previewDoc = null;

    setState(() {
      _error = null;
      _pdfBytes = null;
      _fileName = '';
      _pages.clear();
      _results = [];
      _phase = _SplitPhase.idle;
      _mergeSelected = false;
      _loadingThumbs = true;
    });

    PdfDocument? previewOrphan;
    try {
      if (bytes.isEmpty) {
        throw FormatException('Empty file');
      }
      final pageCount = PdfMergeService.countPages(bytes);
      if (pageCount < 1) {
        throw FormatException('No pages');
      }

      // pdfx may refuse some PDFs that Syncfusion can still split — previews are optional.
      try {
        previewOrphan = await PdfDocument.openData(Uint8List.fromList(bytes));
      } catch (_) {
        previewOrphan = null;
      }

      if (!mounted) {
        await previewOrphan?.close();
        return;
      }

      setState(() {
        _pdfBytes = bytes;
        _previewDoc = previewOrphan;
        previewOrphan = null;
        _fileName = name;
        _baseName = name.toLowerCase().endsWith('.pdf')
            ? name.substring(0, name.length - 4)
            : name;
        _pages.clear();
        for (var i = 0; i < pageCount; i++) {
          _pages.add(_PageThumb(pageIndexZero: i, displayNumber: i + 1));
        }
        _loadingThumbs = false;
      });
    } catch (_) {
      await previewOrphan?.close();
      if (!mounted) return;
      setState(() {
        _loadingThumbs = false;
        _pdfBytes = null;
        _previewDoc = null;
        _fileName = '';
        _pages.clear();
        _error = 'Could not read this PDF. It may be corrupt or encrypted.';
      });
    }
  }

  void _removePdf() {
    final doc = _previewDoc;
    setState(() {
      _pdfBytes = null;
      _previewDoc = null;
      _fileName = '';
      _pages.clear();
      _results = [];
      _phase = _SplitPhase.idle;
      _mergeSelected = false;
      _error = null;
    });
    unawaited(doc?.close());
  }

  void _togglePage(int pageIndexZero) {
    setState(() {
      for (final p in _pages) {
        if (p.pageIndexZero == pageIndexZero) {
          p.selected = !p.selected;
          break;
        }
      }
      if (_phase == _SplitPhase.done) {
        _results = [];
        _phase = _SplitPhase.idle;
      }
    });
  }

  void _toggleMergeSelected(bool? v) {
    if (v == null) return;
    setState(() {
      _mergeSelected = v;
      if (_phase == _SplitPhase.done) {
        _results = [];
        _phase = _SplitPhase.idle;
      }
    });
  }

  Future<void> _runSplitOrMerge() async {
    final bytes = _pdfBytes;
    if (bytes == null || _pages.isEmpty) return;

    final selectedIdx = _pages
        .where((p) => p.selected)
        .map((p) => p.pageIndexZero)
        .toList();
    if (selectedIdx.isEmpty) {
      setState(() => _error = 'Select at least one page to split.');
      return;
    }

    setState(() {
      _error = null;
      _phase = _SplitPhase.working;
      _results = [];
    });

    try {
      if (_mergeSelected) {
        final out = await PdfSplitService.mergeSelectedPages(
          bytes,
          selectedIdx,
        );
        if (!mounted) return;
        setState(() {
          _results = [
            _SplitResult(fileName: '$_baseName-selected.pdf', bytes: out),
          ];
          _phase = _SplitPhase.done;
        });
      } else {
        final outs = await PdfSplitService.extractPagesAsSeparatePdfs(
          bytes,
          selectedIdx,
        );
        if (!mounted) return;
        final named = <_SplitResult>[];
        for (var i = 0; i < selectedIdx.length; i++) {
          final idx = selectedIdx[i];
          final human = _pages
              .firstWhere((p) => p.pageIndexZero == idx)
              .displayNumber;
          named.add(
            _SplitResult(
              fileName: '$_baseName-page-$human.pdf',
              bytes: outs[i],
            ),
          );
        }
        setState(() {
          _results = named;
          _phase = _SplitPhase.done;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Split failed. The PDF may be encrypted or damaged.';
        _phase = _SplitPhase.idle;
      });
    }
  }

  void _backToPages() {
    setState(() {
      _results = [];
      _phase = _SplitPhase.idle;
      _error = null;
    });
  }

  Future<void> _openResult(_SplitResult r) async {
    final dir = await getTemporaryDirectory();
    final safe = r.fileName.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await File(path).writeAsBytes(r.bytes, flush: true);
    await OpenFilex.open(path);
  }

  Future<void> _compressResult(_SplitResult r) async {
    await widget.onCompressPdf(r.bytes);
  }

  int get _selectedCount => _pages.where((p) => p.selected).length;

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
              'Split a PDF',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose the pages you want, then extract them as separate files '
              'or combine them into one. No files are uploaded to our servers for splitting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (_pdfBytes == null && !_loadingThumbs) _buildEmptyDropzone(),
            if (_pdfBytes != null || _loadingThumbs) _buildLoadedSection(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(_error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDropzone() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickPdf,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
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
                  Icons.call_split_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drag & drop a PDF here',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'or tap to browse',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'One PDF at a time — all pages will be shown below',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedSection() {
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
                    _loadingThumbs ? 'Loading…' : _fileName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_pages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'} · '
                        '$_selectedCount selected',
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
              onPressed: _loadingThumbs ? null : _removePdf,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
              label: Text(
                'Choose another PDF',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingThumbs)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Opening PDF…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          _buildPageGrid(),
        if (!_loadingThumbs && _pages.isNotEmpty) ...[
          const SizedBox(height: 20),
          if (_phase != _SplitPhase.done) _buildActions(),
          if (_phase == _SplitPhase.done && _results.isNotEmpty)
            _buildDoneCard(),
        ],
      ],
    );
  }

  Widget _buildPageGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxW = constraints.maxWidth;
        var cross = (maxW / 120).floor().clamp(2, 5);
        if (maxW < 360) cross = 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.72,
          ),
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            final p = _pages[index];
            return _buildPageTile(p);
          },
        );
      },
    );
  }

  Widget _buildPageTile(_PageThumb p) {
    final selected = p.selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _togglePage(p.pageIndexZero),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryBorder : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.panelBackground,
                      child: Opacity(
                        opacity: selected ? 1 : 0.65,
                        child: _previewDoc != null
                            ? SplitPdfTextureTile(
                                key: ValueKey<int>(
                                  Object.hash(_previewDoc!.id, p.displayNumber),
                                ),
                                document: _previewDoc!,
                                pageNumber: p.displayNumber,
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
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    child: Text(
                      'Page ${p.displayNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => _togglePage(p.pageIndexZero),
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.primary;
                          }
                          return null;
                        }),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
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

  Widget _buildActions() {
    final busy = _phase == _SplitPhase.working;
    final canRun = _selectedCount > 0 && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggleMergeSelected(!_mergeSelected),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _mergeSelected,
                      onChanged: _toggleMergeSelected,
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return null;
                      }),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Merge selected pages into a single PDF',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'When unchecked, each selected page is saved as its own separate PDF.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: canRun ? _runSplitOrMerge : null,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _mergeSelected
                      ? Icons.merge_type_rounded
                      : Icons.call_split_rounded,
                  size: 22,
                ),
          label: Text(
            busy
                ? (_mergeSelected ? 'Merging…' : 'Splitting…')
                : (_mergeSelected
                      ? 'Merge selected pages'
                      : 'Split selected pages'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.textTertiary.withValues(
              alpha: 0.35,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_selectedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Select at least one page',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }

  Widget _buildDoneCard() {
    final merge = _mergeSelected;
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
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _results.length == 1
                          ? 'Done!'
                          : '${_results.length} PDFs ready',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      merge
                          ? 'Selected pages merged into one file.'
                          : 'Each selected page is a separate PDF.',
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
          for (final r in _results) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    r.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openResult(r),
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: const Text('Open'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _compressResult(r),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('Compress'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          TextButton(
            onPressed: _backToPages,
            child: Text(
              'Back to pages',
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
}
