import 'dart:io';
import 'package:flutter/services.dart';

class FileProviderHelper {
  static const _channel = MethodChannel('com.ngenou.app/file_provider');

  /// Converts a local file path to a content:// URI via Android's FileProvider.
  /// Returns null on non-Android platforms or on error.
  static Future<String?> getContentUri(String filePath) async {
    if (!Platform.isAndroid) return null;
    try {
      final uri = await _channel.invokeMethod<String>('getUriForFile', filePath);
      return uri;
    } catch (e) {
      return null;
    }
  }
}
