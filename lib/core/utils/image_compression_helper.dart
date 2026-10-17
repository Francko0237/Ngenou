import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Utilitaire de compression d'images équilibrée (non agressive)
/// pour optimiser les temps de chargement et le stockage des cours.
class ImageCompressionHelper {
  static const int defaultMaxWidth = 1080;
  static const int defaultMaxHeight = 720;
  static const int defaultQuality = 80; // Compression douce (80%), qualité visuelle préservée

  /// Sélectionne une image depuis la galerie ou la caméra avec compression modérée intégrée.
  static Future<String?> pickAndCompressCoverImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: defaultMaxWidth.toDouble(),
        maxHeight: defaultMaxHeight.toDouble(),
        imageQuality: defaultQuality,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      Uint8List bytes = await file.readAsBytes();

      // Si le fichier dépasse 400 Ko (cas de certaines plateformes de bureau),
      // appliquer un redimensionnement via le moteur graphique
      if (bytes.lengthInBytes > 400 * 1024) {
        bytes = await compressRawBytes(bytes, maxWidth: 960, maxHeight: 600);
      }

      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Erreur lors de la sélection et compression de l\'image : $e');
      return null;
    }
  }

  /// Redimensionne des octets bruts d'image sans dépendance externe
  static Future<Uint8List> compressRawBytes(
    Uint8List bytes, {
    int maxWidth = defaultMaxWidth,
    int maxHeight = defaultMaxHeight,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Fallback compression bytes : $e');
    }
    return bytes;
  }
}
