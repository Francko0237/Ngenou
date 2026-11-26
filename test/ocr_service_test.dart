import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou/core/services/ocr_service.dart';

void main() {
  test('cleanExtractedText normalizes whitespace and line breaks', () {
    const raw = 'Ligne 1   avec   espaces\r\n\r\n\r\n\r\nLigne 2\t\tfin';
    expect(OcrService.cleanExtractedText(raw), 'Ligne 1 avec espaces\n\nLigne 2 fin');
  });

  test('prepareForPrompt truncates at maxChars', () {
    final longText = 'a' * 150;
    final prepared = OcrService.prepareForPrompt(longText, maxChars: 50);
    expect(prepared.startsWith('a' * 50), isTrue);
    expect(prepared.contains('tronqué à 50 caractères'), isTrue);
  });

  test('countWords and countLines return expected counts', () {
    const sample = 'Bonjour Ngenou\nDeuxième ligne';
    expect(OcrService.countWords(sample), 4);
    expect(OcrService.countLines(sample), 2);
  });

  if (Platform.isWindows) {
    test('Windows native OCR extracts text from PNG', () async {
      final file = File('${Directory.systemTemp.path}\\test_ocr.png');
      if (await file.exists()) {
        final text = await OcrService.extractTextFromImage(file);
        expect(text.toLowerCase(), contains('ngenou'));
      }
    });
  }
}
