import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/ngenou_extension.dart';
import '../../core/services/extensions_service.dart';
import '../../core/services/extension_validator.dart';
import '../../core/widgets/extension_download_dialog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../terminal/terminal_page.dart';
import '../math_tools/fractions_visualizer_page.dart';
import '../math_tools/nombres_relatifs_page.dart';
import '../math_tools/conversion_unites_page.dart';
import 'universal_dynamic_extension_runtime.dart';

/// Hôte universel d'exécution d'extensions Ngenou.
/// Valide automatiquement la conformité de l'extension et charge le moteur
/// d'exécution approprié sans nécessiter de modification du routeur principal.
class ExtensionHostPage extends StatefulWidget {
  final String extensionId;

  const ExtensionHostPage({super.key, required this.extensionId});

  @override
  State<ExtensionHostPage> createState() => _ExtensionHostPageState();
}

class _ExtensionHostPageState extends State<ExtensionHostPage> {
  ExtensionValidationResult? _validationResult;
  bool _isValidating = true;
  Map<String, dynamic>? _bundleData;

  @override
  void initState() {
    super.initState();
    _validateAndInit();
  }

  Future<void> _validateAndInit() async {
    setState(() => _isValidating = true);
    final service = context.read<ExtensionsService>();
    if (!service.isInitialized) {
      await service.init();
    }

    final ext = service.getExtensionById(widget.extensionId);
    if (ext != null) {
      _validationResult = ExtensionValidator.validate(ext);
      if (ext.isInstalled) {
        await _loadLocalBundle(ext.id);
      }
    }

    if (mounted) {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _loadLocalBundle(String extId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bundleFile = File(
        p.join(appDir.path, 'ngenou_extensions', extId, 'bundle.json'),
      );
      if (await bundleFile.exists()) {
        final content = await bundleFile.readAsString();
        _bundleData = json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ExtensionHostPage] Erreur lecture bundle local: $e');
    }
  }

  void _showConformityReport(NgenouExtension ext) {
    final result = _validationResult;
    if (result == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isValid
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: result.isValid
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  result.isValid
                      ? 'Extension Certifiée Conforme'
                      : 'Anomalies de conformité',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Spécification standard Ngenou v1.0 • ${ext.id}',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (result.isValid) ...[
              const Text(
                '✓ Identifiant valide et sécurisé\n'
                '✓ Schéma et métadonnées conformes\n'
                '✓ Intégration autonome validée',
                style: TextStyle(height: 1.6, fontSize: 13.5),
              ),
            ] else ...[
              ...result.errors.map(
                (err) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          err,
                          style: const TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...result.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ExtensionsService>();
    final ext = service.getExtensionById(widget.extensionId);

    if (_isValidating || service.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (ext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extension')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.extension_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Extension "${widget.extensionId}" introuvable',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Si pas encore installée : prompt de téléchargement
    if (!ext.isInstalled) {
      return Scaffold(
        appBar: AppBar(title: Text(ext.nom)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ext.icon, size: 56, color: ext.color),
                const SizedBox(height: 16),
                Text(
                  ext.nom,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Taille : ${ext.taille} • Par ${ext.auteur}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await promptExtensionDownload(
                      context,
                      ext.id,
                      featureName: ext.nom,
                    );
                    if (ok && mounted) {
                      await _validateAndInit();
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Télécharger (${ext.taille})'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si non-conforme
    if (_validationResult != null && !_validationResult!.isValid) {
      return Scaffold(
        appBar: AppBar(title: Text(ext.nom)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Extension non conforme aux spécifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showConformityReport(ext),
                  icon: const Icon(Icons.rule_rounded),
                  label: const Text('Voir le rapport de validation'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si l'extension est conforme et installée, router dynamiquement vers son moteur
    return _buildRuntimeEnvironment(ext);
  }

  /// Registre des pages natives disponibles dans l'application.
  /// Chaque clé correspond à la valeur "nativePage" déclarée dans le bundle.json
  /// de l'extension. L'app n'a AUCUNE connaissance des IDs d'extensions —
  /// c'est le bundle.json téléchargé qui indique quelle page utiliser.
  static final Map<String, Widget Function()> _nativePageRegistry = {
    'terminal': () => const TerminalPage(),
    'fractions_visualizer': () => const FractionsVisualizerPage(),
    'nombres_relatifs': () => const NombresRelatifsPage(),
    'conversion_unites': () => const ConversionUnitesPage(),
  };

  Widget _buildRuntimeEnvironment(NgenouExtension ext) {
    // Stratégie de routage 100% dynamique basée sur le bundle.json :
    //
    // 1. Si le bundle.json déclare "engine": "native_page" et "nativePage": "<key>",
    //    on cherche dans le registre local des pages natives compilées.
    //
    // 2. Sinon, on utilise le moteur universel déclaratif qui construit
    //    l'interface à partir des blocs JSON (tabs, sliders, etc.).
    //
    // 3. Si aucun bundle n'est disponible, on propose le téléchargement.

    if (_bundleData != null) {
      final engine = _bundleData!['engine'] as String?;
      final nativePage = _bundleData!['nativePage'] as String?;

      // Route vers une page native haute performance si déclarée
      if (engine == 'native_page' && nativePage != null) {
        final pageBuilder = _nativePageRegistry[nativePage];
        if (pageBuilder != null) {
          return pageBuilder();
        }
        // La page native n'est pas disponible dans cette version de l'app :
        // on tombe en mode déclaratif universel (dégradé gracieux)
        debugPrint(
          '[ExtensionHost] Page native "$nativePage" non trouvée dans le registre. '
          'Fallback vers le moteur déclaratif universel.',
        );
      }

      // Moteur universel déclaratif pour toute extension dynamique
      return UniversalDynamicExtensionRuntime(
        bundleData: _bundleData!,
        extension: ext,
      );
    }

    // Aucun bundle local disponible → proposer la réinstallation
    return Scaffold(
      appBar: AppBar(title: Text(ext.nom)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ext.icon, size: 56, color: ext.color),
              const SizedBox(height: 16),
              Text(
                ext.nom,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                'L\'extension nécessite une mise à jour pour fonctionner correctement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final service = context.read<ExtensionsService>();
                  await service.installExtension(ext);
                  if (mounted) await _validateAndInit();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
