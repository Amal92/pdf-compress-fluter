import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Split / merge selected pages from a single PDF using
/// [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf).
class PdfSplitService {
  PdfSplitService._();

  static void _appendPage(PdfDocument src, int zeroBasedIndex, PdfDocument dest) {
    final srcPage = src.pages[zeroBasedIndex];
    final pageSize = srcPage.size;
    final template = srcPage.createTemplate();
    final section = dest.sections!.add();
    final settings = PdfPageSettings(pageSize);
    settings.margins = PdfMargins()..all = 0;
    section.pageSettings = settings;
    final newPage = section.pages.add();
    newPage.graphics.drawPdfTemplate(template, Offset.zero, pageSize);
  }

  /// [pageIndicesZeroBased] in the order they should appear in the output PDF.
  static Future<Uint8List> mergeSelectedPages(
    Uint8List sourceBytes,
    List<int> pageIndicesZeroBased,
  ) async {
    final src = PdfDocument(inputBytes: sourceBytes);
    final merged = PdfDocument();
    try {
      for (final i in pageIndicesZeroBased) {
        if (i < 0 || i >= src.pages.count) {
          throw StateError('Invalid page index $i');
        }
        _appendPage(src, i, merged);
      }
      final bytes = await merged.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      merged.dispose();
    }
  }

  /// One PDF per index, in the same order as [pageIndicesZeroBased].
  static Future<List<Uint8List>> extractPagesAsSeparatePdfs(
    Uint8List sourceBytes,
    List<int> pageIndicesZeroBased,
  ) async {
    final src = PdfDocument(inputBytes: sourceBytes);
    try {
      final results = <Uint8List>[];
      for (final i in pageIndicesZeroBased) {
        if (i < 0 || i >= src.pages.count) {
          throw StateError('Invalid page index $i');
        }
        final single = PdfDocument();
        try {
          _appendPage(src, i, single);
          final bytes = await single.save();
          results.add(Uint8List.fromList(bytes));
        } finally {
          single.dispose();
        }
      }
      return results;
    } finally {
      src.dispose();
    }
  }
}
