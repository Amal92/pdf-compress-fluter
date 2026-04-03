import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Local PDF merge using [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf).
class PdfMergeService {
  PdfMergeService._();

  /// Merges PDFs in order; each source page keeps its original dimensions.
  static Future<Uint8List> mergeOrdered(List<Uint8List> pdfBuffers) async {
    final merged = PdfDocument();

    try {
      for (final buffer in pdfBuffers) {
        final src = PdfDocument(inputBytes: buffer);
        try {
          final pageCount = src.pages.count;
          for (int i = 0; i < pageCount; i++) {
            final srcPage = src.pages[i];
            final pageSize = srcPage.size;
            final template = srcPage.createTemplate();

            final section = merged.sections!.add();
            final settings = PdfPageSettings(pageSize);
            settings.margins = PdfMargins()..all = 0;
            section.pageSettings = settings;

            final newPage = section.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              pageSize,
            );
          }
        } finally {
          src.dispose();
        }
      }

      final bytes = await merged.save();
      return Uint8List.fromList(bytes);
    } finally {
      merged.dispose();
    }
  }

  static int countPages(Uint8List buffer) {
    final doc = PdfDocument(inputBytes: buffer);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }
}
