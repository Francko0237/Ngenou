import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {
  /// Extrait le texte d'un fichier image (JPEG, PNG, etc.) via Google ML Kit.
  /// Le script "latin" est le plus robuste pour le texte imprimé et manuscrit.
  /// Un tri spatial (Y puis X) est appliqué pour conserver l'agencement visuel.
  static Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // Trier les blocs pour reconstruire la mise en page
      final blocks = recognizedText.blocks.toList();

      blocks.sort((a, b) {
        // Si la différence de hauteur (Y) est minime (< 15 pixels), on les considère
        // sur la même ligne et on trie par position horizontale (X).
        if ((a.boundingBox.top - b.boundingBox.top).abs() < 15) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        // Sinon, on trie de haut en bas (Y).
        return a.boundingBox.top.compareTo(b.boundingBox.top);
      });

      final buffer = StringBuffer();
      double? lastY;

      for (var block in blocks) {
        // Saut de paragraphe si grande différence de hauteur
        if (lastY != null && (block.boundingBox.top - lastY).abs() > 25) {
          buffer.write('\n\n');
        } else if (lastY != null) {
          buffer.write('  '); // Espace entre les colonnes sur la même ligne
        }

        // Remplacer les sauts de ligne internes au bloc par de simples espaces
        // pour laisser notre algorithme gérer la mise en forme.
        buffer.write(block.text.replaceAll('\n', ' '));
        lastY = block.boundingBox.top;
      }

      return buffer.toString().trim();
    } finally {
      textRecognizer.close();
    }
  }

  /// Extrait le texte natif d'un fichier PDF via Syncfusion.
  /// Note : Cela fonctionne parfaitement pour les PDF "textuels". Pour les PDF
  /// constitués uniquement de scans (images imbriquées), le texte retourné sera vide.
  static Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText();

      document.dispose();

      return text.trim();
    } catch (e) {
      throw Exception(
        'Impossible de lire le PDF. Le fichier est peut-être corrompu ou protégé.',
      );
    }
  }
}
