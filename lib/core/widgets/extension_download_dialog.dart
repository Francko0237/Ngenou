import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ngenou_extension.dart';
import '../services/extensions_service.dart';

/// Boîte de dialogue demandant à l'utilisateur de télécharger une extension
/// si celle-ci n'est pas encore installée.
/// Renvoie true si l'extension est installée (ou déjà installée), false sinon.
Future<bool> promptExtensionDownload(
  BuildContext context,
  String extensionId, {
  String? featureName,
}) async {
  final service = context.read<ExtensionsService>();

  // Si pas encore initialisé, s'assurer que c'est fait
  if (!service.isInitialized) {
    await service.init();
  }

  // Si déjà installée, accès direct
  if (service.isInstalled(extensionId)) {
    return true;
  }

  if (!context.mounted) return false;

  final ext = service.getExtensionById(extensionId);
  if (ext == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extension introuvable dans le catalogue.'),
      ),
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ExtensionDownloadModal(
      extension: ext,
      featureName: featureName,
    ),
  );

  return result ?? false;
}

class _ExtensionDownloadModal extends StatefulWidget {
  final NgenouExtension extension;
  final String? featureName;

  const _ExtensionDownloadModal({
    required this.extension,
    this.featureName,
  });

  @override
  State<_ExtensionDownloadModal> createState() =>
      _ExtensionDownloadModalState();
}

class _ExtensionDownloadModalState extends State<_ExtensionDownloadModal> {
  bool _isDownloading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    final service = context.read<ExtensionsService>();
    final success = await service.installExtension(widget.extension);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isDownloading = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Échec du téléchargement. Vérifiez votre connexion internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final ext = widget.extension;
    final extColor = ext.color;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF16161E) : Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône et En-tête
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        extColor.withValues(alpha: 0.22),
                        extColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: extColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(ext.icon, color: extColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.featureName ?? 'Module additionnel requis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ext.nom,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              ext.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.75),
              ),
            ),

            const SizedBox(height: 16),

            // Boîte d'informations sur la taille et la source
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF4F5F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_zip_rounded,
                          size: 18, color: extColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Taille :',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: extColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ext.taille,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: extColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 8),
                      Text(
                        'Auteur :',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ext.auteur,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Téléchargement en cours (${ext.taille})...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ],
              ),
            ],

            if (_isSuccess) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2ECC71), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Extension installée ! Ouverture...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE74C3C),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (!_isDownloading && !_isSuccess) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton.icon(
            onPressed: _startDownload,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              'Télécharger (${ext.taille})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
