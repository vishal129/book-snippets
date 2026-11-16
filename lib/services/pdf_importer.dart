import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import 'chunker.dart';

typedef ProgressCallback = void Function(int done, int total, String stage);

class ImportedBook {
  ImportedBook(this.title, this.totalPages, this.snippets, this.ocrPages);
  final String title;
  final int totalPages;
  final List<Snippet> snippets;
  final int ocrPages;
}

class PdfImporter {
  /// Pages with fewer extracted characters than this are treated as scanned.
  static const _minCharsForTextPage = 40;

  /// Width in pixels used when rasterising a page for OCR.
  static const _ocrWidth = 1600;

  Future<ImportedBook> import(String path,
      {required ProgressCallback onProgress}) async {
    final doc = await PdfDocument.openFile(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final total = doc.pages.length;
      final pages = <PageText>[];
      var ocrCount = 0;

      for (var i = 0; i < total; i++) {
        final page = doc.pages[i];
        onProgress(i, total, 'Reading page ${i + 1} of $total');

        final extracted = (await page.loadText())?.fullText ?? '';
        var text = extracted;

        if (extracted.trim().length < _minCharsForTextPage) {
          onProgress(i, total, 'Scanned page ${i + 1} of $total, running OCR');
          final ocr = await _ocrPage(page, recognizer);
          if (ocr.trim().length > extracted.trim().length) {
            text = ocr;
            ocrCount++;
          }
        }
        pages.add(PageText(i + 1, text));
      }

      onProgress(total, total, 'Splitting into snippets');
      await Future<void>.delayed(Duration.zero); // let the UI repaint
      final snippets = chunkBook(pages);

      return ImportedBook(_titleFromPath(path), total, snippets, ocrCount);
    } finally {
      await recognizer.close();
      doc.dispose();
    }
  }

  Future<String> _ocrPage(PdfPage page, TextRecognizer recognizer) async {
    final scale = _ocrWidth / page.width;
    final img = await page.render(
      width: (page.width * scale).round(),
      height: (page.height * scale).round(),
    );
    if (img == null) return '';
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          img.pixels, img.width, img.height, ui.PixelFormat.bgra8888, completer.complete);
      final uiImage = await completer.future;
      final bytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (bytes == null) return '';

      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/ocr_page.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      return result.text;
    } finally {
      img.dispose();
    }
  }

  String _titleFromPath(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final base = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    return base.replaceAll(RegExp(r'[_]+'), ' ').trim();
  }
}
