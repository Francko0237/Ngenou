import 'dart:convert';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../config/ai_config.dart';

/// Exception spécifique levée lorsqu'un PDF dépasse le plafond de pages.
class PdfPageLimitException implements Exception {
  final int pageCount;
  final int maxPages;

  const PdfPageLimitException({
    required this.pageCount,
    required this.maxPages,
  });

  @override
  String toString() =>
      'Ce PDF contient $pageCount pages. La limite maximale autorisée est de $maxPages pages.';
}

/// Résultat structuré d'une extraction locale de document/image.
class OcrExtractionResult {
  final String text;
  final int? pageCount;
  final bool wasTruncated;

  const OcrExtractionResult({
    required this.text,
    this.pageCount,
    this.wasTruncated = false,
  });
}

class OcrService {
  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
  };

  static const Set<String> textExtensions = {
    'txt',
    'md',
    'csv',
    'json',
    'jsonl',
    'algo',
    'dart',
    'py',
    'js',
    'ts',
    'html',
    'css',
    'xml',
    'yaml',
    'yml',
    'c',
    'cpp',
    'h',
    'java',
    'sql',
    'log',
  };

  /// Nettoie le texte extrait localement (0 token dépensé) :
  /// normalise les sauts de ligne, supprime les espaces/tabulations multiples
  /// et condense les sauts de paragraphe excessifs.
  static String cleanExtractedText(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim())
        .toList();
    final joined = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return joined.trim();
  }

  /// Prépare un texte extrait pour le prompt IA en respectant le plafond de
  /// caractères ([AiConfig.maxAttachmentChars]) afin de maîtriser les tokens.
  static String prepareForPrompt(
    String cleanedText, {
    int maxChars = AiConfig.maxAttachmentChars,
  }) {
    if (cleanedText.length <= maxChars) return cleanedText;
    final cut = cleanedText.substring(0, maxChars).trimRight();
    return '$cut\n\n[... Contenu tronqué à $maxChars caractères pour préserver les tokens ...]';
  }

  /// Compte approximativement le nombre de mots utiles dans un texte.
  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// Compte le nombre de lignes non vides/totales d'un texte.
  static int countLines(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split('\n').length;
  }

  /// Extrait le texte d'une image de façon native selon la plateforme :
  /// - Android / iOS : Google ML Kit (tri spatial Y puis X)
  /// - Windows : Windows.Media.Ocr (WinRT natif via PowerShell)
  /// - Linux : Tesseract OCR natif
  static Future<String> extractTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Le fichier image sélectionné est introuvable.');
    }

    final sizeBytes = await imageFile.length();
    if (sizeBytes == 0) {
      throw Exception('L\'image sélectionnée est vide.');
    }
    if (sizeBytes > AiConfig.maxImageSizeBytes) {
      final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      final maxMb = (AiConfig.maxImageSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      throw Exception(
        'Image trop volumineuse ($mb Mo). La taille maximale autorisée est de $maxMb Mo.',
      );
    }

    String rawText;
    if (Platform.isAndroid || Platform.isIOS) {
      rawText = await _extractImageMlKit(imageFile);
    } else if (Platform.isWindows) {
      rawText = await _extractImageWindowsNative(imageFile);
    } else if (Platform.isLinux) {
      rawText = await _extractImageLinuxTesseract(imageFile);
    } else {
      throw Exception(
        'La reconnaissance de texte (OCR) sur image n\'est pas prise en charge sur cette plateforme.',
      );
    }

    final cleaned = cleanExtractedText(rawText);
    if (cleaned.length < AiConfig.minOcrUsefulChars) {
      throw Exception(
        'Aucun texte lisible détecté sur cette image (photo floue, trop sombre ou sans texte).',
      );
    }
    return cleaned;
  }

  static Future<String> _extractImageMlKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      final blocks = recognizedText.blocks.toList();
      blocks.sort((a, b) {
        if ((a.boundingBox.top - b.boundingBox.top).abs() < 15) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        return a.boundingBox.top.compareTo(b.boundingBox.top);
      });

      final buffer = StringBuffer();
      double? lastY;

      for (final block in blocks) {
        if (lastY != null && (block.boundingBox.top - lastY).abs() > 25) {
          buffer.write('\n\n');
        } else if (lastY != null) {
          buffer.write('  ');
        }
        buffer.write(block.text.replaceAll('\n', ' '));
        lastY = block.boundingBox.top;
      }

      return buffer.toString().trim();
    } finally {
      await textRecognizer.close();
    }
  }

  static String _encodePowerShellUtf16LeBase64(String script) {
    final units = script.codeUnits;
    final bytes = <int>[];
    for (final u in units) {
      bytes.add(u & 0xFF);
      bytes.add((u >> 8) & 0xFF);
    }
    return base64Encode(bytes);
  }

  static Future<String> _extractImageWindowsNative(File imageFile) async {
    const script = r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  $netTask.Result
}
[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapTransform,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapPixelFormat,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapAlphaMode,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.ExifOrientationMode,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.ColorManagementMode,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrResult,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null

$imgPath = $env:NGENOU_OCR_PATH
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($imgPath)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
try {
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $w = $decoder.PixelWidth
  $h = $decoder.PixelHeight
  $maxDim = 2500
  $transform = New-Object Windows.Graphics.Imaging.BitmapTransform
  if ($w -gt $maxDim -or $h -gt $maxDim) {
    $scale = [Math]::Min($maxDim / [double]$w, $maxDim / [double]$h)
    $transform.ScaledWidth = [uint32][Math]::Max(1, [Math]::Round($w * $scale))
    $transform.ScaledHeight = [uint32][Math]::Max(1, [Math]::Round($h * $scale))
  }
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync(
    [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
    [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied,
    $transform,
    [Windows.Graphics.Imaging.ExifOrientationMode]::RespectExifOrientation,
    [Windows.Graphics.Imaging.ColorManagementMode]::ColorManageToSRgb
  )) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  if ($null -eq $engine) {
    $langs = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
    if ($langs.Count -gt 0) {
      $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($langs[0])
    }
  }
  if ($null -eq $engine) {
    Write-Error 'NO_WINRT_OCR_ENGINE'
    exit 2
  }
  $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  foreach ($line in $result.Lines) {
    Write-Output $line.Text
  }
} finally {
  $stream.Dispose()
}
''';

    final encoded = _encodePowerShellUtf16LeBase64(script);
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      environment: {'NGENOU_OCR_PATH': imageFile.absolute.path},
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (res.exitCode == 2 ||
        (res.stderr?.toString().contains('NO_WINRT_OCR_ENGINE') ?? false)) {
      throw Exception(
        'Aucun module de langue OCR Windows n\'est installé sur ce PC (Paramètres Windows > Langue).',
      );
    }
    if (res.exitCode != 0) {
      final errDetail = (res.stderr ?? '').toString().trim();
      throw Exception(
        errDetail.isNotEmpty
            ? 'OCR Windows impossible : ${errDetail.split('\n').first}'
            : 'Impossible d\'analyser cette image avec l\'OCR natif Windows.',
      );
    }
    return (res.stdout ?? '').toString().trim();
  }

  static Future<String> _extractImageLinuxTesseract(File imageFile) async {
    try {
      final check = await Process.run('tesseract', ['--version']);
      if (check.exitCode != 0) {
        throw const ProcessException('tesseract', ['--version']);
      }
    } catch (_) {
      throw Exception(
        'OCR Linux indisponible : installez tesseract '
        '(Ubuntu/Debian : sudo apt install tesseract-ocr tesseract-ocr-fra | '
        'Fedora : sudo dnf install tesseract tesseract-langpack-fra).',
      );
    }

    final attempts = <List<String>>[
      [imageFile.absolute.path, 'stdout', '-l', 'fra+eng', '--psm', '6'],
      [imageFile.absolute.path, 'stdout', '-l', 'fra', '--psm', '6'],
      [imageFile.absolute.path, 'stdout', '-l', 'eng', '--psm', '6'],
      [imageFile.absolute.path, 'stdout', '--psm', '6'],
    ];

    ProcessResult? lastRes;
    for (final args in attempts) {
      final res = await Process.run(
        'tesseract',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      lastRes = res;
      if (res.exitCode == 0) {
        return (res.stdout ?? '').toString().trim();
      }
    }

    final err = (lastRes?.stderr ?? '').toString().trim();
    throw Exception(
      err.isNotEmpty
          ? 'Échec OCR Tesseract : ${err.split('\n').first}'
          : 'Échec de la reconnaissance de texte avec Tesseract sur cette image.',
    );
  }

  /// Extrait le texte natif d'un fichier PDF via Syncfusion en appliquant une
  /// limite stricte de pages ([maxPages], défaut [AiConfig.maxPdfPages] = 5).
  static Future<OcrExtractionResult> extractPdfWithDetails(
    File pdfFile, {
    int maxPages = AiConfig.maxPdfPages,
  }) async {
    if (!await pdfFile.exists()) {
      throw Exception('Le fichier PDF sélectionné est introuvable.');
    }

    PdfDocument? document;
    try {
      final bytes = await pdfFile.readAsBytes();
      document = PdfDocument(inputBytes: bytes);

      final pageCount = document.pages.count;
      if (pageCount == 0) {
        throw Exception('Ce fichier PDF ne contient aucune page.');
      }
      if (pageCount > maxPages) {
        throw PdfPageLimitException(pageCount: pageCount, maxPages: maxPages);
      }

      final textExtractor = PdfTextExtractor(document);
      final rawText = textExtractor.extractText();
      final cleaned = cleanExtractedText(rawText);

      if (cleaned.isEmpty) {
        throw Exception(
          'Ce PDF ne contient aucun texte sélectionnable (document probablement scanné en images).',
        );
      }

      return OcrExtractionResult(
        text: cleaned,
        pageCount: pageCount,
        wasTruncated: cleaned.length > AiConfig.maxAttachmentChars,
      );
    } on PdfPageLimitException {
      rethrow;
    } catch (e) {
      if (e is Exception &&
          e.toString().contains('aucun texte sélectionnable')) {
        rethrow;
      }
      if (e is Exception && e.toString().contains('aucune page')) {
        rethrow;
      }
      throw Exception(
        'Impossible de lire le PDF. Le fichier est peut-être corrompu ou protégé par mot de passe.',
      );
    } finally {
      document?.dispose();
    }
  }

  /// Compatibilité avec les appels existants (ex: CourseBuilderWizardPage).
  static Future<String> extractTextFromPdf(File pdfFile) async {
    final result = await extractPdfWithDetails(pdfFile, maxPages: 100);
    return result.text;
  }

  /// Extrait le texte d'un fichier quelconque (image, PDF max 5 pages, texte/code)
  /// et retourne les métadonnées + texte nettoyé prêt à être envoyé.
  static Future<OcrExtractionResult> extractFromAnyFile(
    File file, {
    int maxPdfPages = AiConfig.maxPdfPages,
  }) async {
    if (!await file.exists()) {
      throw Exception('Le fichier sélectionné est introuvable.');
    }

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
    final dotIdx = fileName.lastIndexOf('.');
    final ext = (dotIdx >= 0 && dotIdx < fileName.length - 1)
        ? fileName.substring(dotIdx + 1).toLowerCase()
        : '';

    if (imageExtensions.contains(ext)) {
      final text = await extractTextFromImage(file);
      return OcrExtractionResult(
        text: text,
        wasTruncated: text.length > AiConfig.maxAttachmentChars,
      );
    }

    if (ext == 'pdf') {
      return extractPdfWithDetails(file, maxPages: maxPdfPages);
    }

    if (textExtensions.contains(ext) || ext.isEmpty) {
      final sizeBytes = await file.length();
      if (sizeBytes == 0) {
        throw Exception('Ce fichier texte est vide.');
      }
      if (sizeBytes > AiConfig.maxTextFileSizeBytes) {
        final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final maxMb = (AiConfig.maxTextFileSizeBytes / (1024 * 1024))
            .toStringAsFixed(0);
        throw Exception(
          'Fichier trop volumineux ($mb Mo). La limite maximale est de $maxMb Mo.',
        );
      }

      String raw;
      try {
        final bytes = await file.readAsBytes();
        raw = utf8.decode(bytes, allowMalformed: false);
      } catch (_) {
        raw = await file.readAsString();
      }
      final cleaned = cleanExtractedText(raw);
      if (cleaned.isEmpty) {
        throw Exception('Ce fichier ne contient aucun texte exploitable.');
      }
      return OcrExtractionResult(
        text: cleaned,
        wasTruncated: cleaned.length > AiConfig.maxAttachmentChars,
      );
    }

    throw Exception(
      'Format ".$ext" non pris en charge. Formats acceptés : images, PDF (max $maxPdfPages pages), texte et fichiers de code.',
    );
  }
}
