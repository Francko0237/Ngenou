import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ngenou_extension.dart';

class ExtensionsService extends ChangeNotifier {
  static final ExtensionsService instance = ExtensionsService._internal();
  factory ExtensionsService() => instance;
  ExtensionsService._internal();

  static const String manifestUrl =
      'https://raw.githubusercontent.com/Francko0237/Assets-Ngenou/main/manifest.json';
  static const String repoRawBaseUrl =
      'https://raw.githubusercontent.com/Francko0237/Assets-Ngenou/main';
  static const String _installedKey = 'ngenou_installed_extensions_ids';
  static const String _cachedManifestKey = 'ngenou_extensions_manifest_cache';

  List<NgenouExtension> _extensions = [];
  Set<String> _installedIds = {};
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<NgenouExtension> get extensions => _extensions;
  Set<String> get installedIds => _installedIds;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  bool isInstalled(String id) => _installedIds.contains(id);

  /// Récupère une extension par son identifiant
  NgenouExtension? getExtensionById(String id) {
    try {
      return _extensions.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Charge les extensions (depuis le cache / réseau)
  Future<void> init() async {
    if (_isInitialized) return;
    await _loadInstalledIds();
    await _loadLocalExtensionsFromDisk();
    await loadExtensions();
    _isInitialized = true;
  }

  Future<void> _loadLocalExtensionsFromDisk() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final rootDir = Directory(p.join(appDir.path, 'ngenou_extensions'));
      if (await rootDir.exists()) {
        final subDirs = rootDir.listSync().whereType<Directory>();
        for (final dir in subDirs) {
          final metaFile = File(p.join(dir.path, 'extension.json'));
          if (await metaFile.exists()) {
            final jsonStr = await metaFile.readAsString();
            final map = json.decode(jsonStr) as Map<String, dynamic>;
            final ext = NgenouExtension.fromJson(map, isInstalled: true);
            if (!_extensions.any((e) => e.id == ext.id)) {
              _extensions.add(ext);
            }
            _installedIds.add(ext.id);
          }
        }
      }
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur scan extensions locales: $e');
    }
  }

  Future<void> _loadInstalledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_installedKey) ?? [];
      _installedIds = list.toSet();
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur lecture IDs installés: $e');
      _installedIds = {};
    }
  }

  Future<void> _saveInstalledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_installedKey, _installedIds.toList());
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur sauvegarde IDs: $e');
    }
  }

  /// Récupère la liste des extensions depuis le dépôt GitHub ou le cache
  Future<void> loadExtensions({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonContent;

      if (!forceRefresh) {
        jsonContent = prefs.getString(_cachedManifestKey);
      }

      // Si pas de cache ou si refresh forcé, tenter l'appel réseau
      if (jsonContent == null || forceRefresh) {
        try {
          final res = await http
              .get(Uri.parse(manifestUrl))
              .timeout(const Duration(seconds: 7));
          if (res.statusCode == 200) {
            jsonContent = utf8.decode(res.bodyBytes);
            await prefs.setString(_cachedManifestKey, jsonContent);
          }
        } catch (networkError) {
          debugPrint(
            '[ExtensionsService] Réseau indisponible pour le manifest: $networkError',
          );
          // Si échec réseau, on essaie de réutiliser le cache précédent
          jsonContent = prefs.getString(_cachedManifestKey);
        }
      }

      // Si toujours rien, on utilise la liste par défaut embarquée
      if (jsonContent == null || jsonContent.isEmpty) {
        jsonContent = _bundledFallbackManifest;
      }

      final data = json.decode(jsonContent) as Map<String, dynamic>;
      final list = (data['extensions'] as List<dynamic>?) ?? [];

      _extensions = list.map((item) {
        final extMap = item as Map<String, dynamic>;
        final id = extMap['id'] as String? ?? '';
        return NgenouExtension.fromJson(
          extMap,
          isInstalled: _installedIds.contains(id),
        );
      }).toList();
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur chargement extensions: $e');
      _error = 'Impossible de charger le catalogue des extensions ($e)';
      // Au minimum afficher le fallback
      _loadFallbackList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFallbackList() {
    try {
      final data =
          json.decode(_bundledFallbackManifest) as Map<String, dynamic>;
      final list = (data['extensions'] as List<dynamic>?) ?? [];
      _extensions = list.map((item) {
        final extMap = item as Map<String, dynamic>;
        final id = extMap['id'] as String? ?? '';
        return NgenouExtension.fromJson(
          extMap,
          isInstalled: _installedIds.contains(id),
        );
      }).toList();
    } catch (_) {}
  }

  /// Installe une extension (télécharge ses fichiers localement)
  Future<bool> installExtension(NgenouExtension ext) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final extDir = Directory(
        p.join(appDir.path, 'ngenou_extensions', ext.id),
      );
      if (!await extDir.exists()) {
        await extDir.create(recursive: true);
      }

      // Téléchargement des fichiers déclarés + bundle.json
      final filesToDownload = <String>{
        ...ext.files,
        'bundle.json',
        'README.md',
      };
      for (final fileName in filesToDownload) {
        final fileUrl = '$repoRawBaseUrl/extensions/${ext.id}/$fileName';
        try {
          final res = await http
              .get(Uri.parse(fileUrl))
              .timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            final targetFile = File(p.join(extDir.path, fileName));
            await targetFile.writeAsBytes(res.bodyBytes);
          }
        } catch (fileErr) {
          debugPrint(
            '[ExtensionsService] Téléchargement $fileName échoué ($fileErr), ignoré',
          );
        }
      }

      // Sauvegarde des métadonnées locales
      final metaFile = File(p.join(extDir.path, 'extension.json'));
      await metaFile.writeAsString(json.encode(ext.toJson()));

      _installedIds.add(ext.id);
      await _saveInstalledIds();

      // Mettre à jour l'instance locale
      _extensions = _extensions.map((e) {
        if (e.id == ext.id) {
          return e.copyWith(isInstalled: true);
        }
        return e;
      }).toList();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur lors de l\'installation: $e');
      return false;
    }
  }

  /// Désinstalle une extension
  Future<bool> uninstallExtension(String extId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final extDir = Directory(p.join(appDir.path, 'ngenou_extensions', extId));
      if (await extDir.exists()) {
        await extDir.delete(recursive: true);
      }

      _installedIds.remove(extId);
      await _saveInstalledIds();

      // Mettre à jour l'instance locale
      _extensions = _extensions.map((e) {
        if (e.id == extId) {
          return e.copyWith(isInstalled: false);
        }
        return e;
      }).toList();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ExtensionsService] Erreur désinstallation: $e');
      return false;
    }
  }

  /// Récupère le dossier local d'une extension installée
  Future<Directory?> getInstalledExtensionDirectory(String extId) async {
    if (!isInstalled(extId)) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final extDir = Directory(p.join(appDir.path, 'ngenou_extensions', extId));
    if (await extDir.exists()) return extDir;
    return null;
  }

  // Fallback vide si aucun cache ni réseau n'est disponible au 1er lancement
  static const String _bundledFallbackManifest =
      '{"version": "1.0.0", "extensions": []}';
}
