import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paramètres
// ─────────────────────────────────────────────────────────────────────────────

const _kMaxWidth = 960;
const _kMaxHeight = 640;
const _kQuality = 78; // qualité JPEG pour ImagePicker
const _kMaxBytes = 350 * 1024; // 350 Ko — seuil avant 2ème passe

// ─────────────────────────────────────────────────────────────────────────────
// Traitement dans un isolate séparé (fonction top-level obligatoire)
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _resizeInIsolate(Uint8List bytes) async {
  ui.Codec? codec;
  ui.FrameInfo? frame;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _kMaxWidth,
      targetHeight: _kMaxHeight,
    );
    frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) return data.buffer.asUint8List();
  } catch (e) {
    debugPrint('[ImageCompression] isolate error: $e');
  } finally {
    // Libération explicite des ressources GPU — crucial pour éviter le crash
    try {
      frame?.image.dispose();
    } catch (_) {}
    try {
      codec?.dispose();
    } catch (_) {}
  }
  return bytes; // fallback : retourne les bytes d'origine
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper public
// ─────────────────────────────────────────────────────────────────────────────

class ImageCompressionHelper {
  /// Sélectionne et compresse une image de couverture.
  ///
  /// Étape 1 : ImagePicker réduit déjà à 960×640 + qualité 78
  ///           → résultat JPEG typiquement < 200 Ko
  /// Étape 2 : Si encore > 350 Ko (ex. format PNG/HEIC depuis galerie),
  ///           on redimensionne dans un `compute()` isolate pour ne JAMAIS
  ///           bloquer ni crasher le thread principal
  static Future<String?> pickAndCompressCoverImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: _kMaxWidth.toDouble(),
        maxHeight: _kMaxHeight.toDouble(),
        imageQuality: _kQuality,
      );

      if (picked == null) return null;

      Uint8List bytes = await File(picked.path).readAsBytes();

      // Recompression uniquement si le fichier est encore trop lourd
      if (bytes.lengthInBytes > _kMaxBytes) {
        bytes = await compute(_resizeInIsolate, bytes);
      }

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('[ImageCompression] pick error: $e');
      return null;
    }
  }

  /// Compresse des bytes bruts dans un isolate.
  static Future<Uint8List> compressRawBytes(
    Uint8List bytes, {
    int maxWidth = _kMaxWidth,
    int maxHeight = _kMaxHeight,
  }) async {
    if (bytes.lengthInBytes <= _kMaxBytes) return bytes;
    try {
      return await compute(_resizeInIsolate, bytes);
    } catch (e) {
      debugPrint('[ImageCompression] compressRawBytes error: $e');
      return bytes;
    }
  }
}
