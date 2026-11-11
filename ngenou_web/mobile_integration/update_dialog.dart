import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Boîte de dialogue de mise à jour pour l'application mobile Ngenou
class UpdateDialog extends StatelessWidget {
  final String versionName;
  final int versionCode;
  final String title;
  final String notes;
  final String apkUrl;
  final bool forceUpdate;
  final List<Map<String, String>> features;

  const UpdateDialog({
    super.key,
    required this.versionName,
    required this.versionCode,
    required this.title,
    required this.notes,
    required this.apkUrl,
    required this.forceUpdate,
    this.features = const [],
  });

  Future<void> _handleDownload(BuildContext context) async {
    final uri = Uri.parse(
      apkUrl.isNotEmpty ? apkUrl : 'https://ngenou.top/nouveautes',
    );
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Échec de l'ouverture
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si forceUpdate est actif, empêcher le retour arrière
    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F1A33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1E2E52), width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3CC8E8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF3CC8E8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forceUpdate
                            ? 'Mise à jour obligatoire'
                            : 'Nouvelle version disponible',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF3EEE2),
                        ),
                      ),
                      Text(
                        'Version $versionName',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3CC8E8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF3EEE2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9BA8C4),
                    height: 1.5,
                  ),
                ),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Au programme de cette version :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0B93A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...features.map((feat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF3CC8E8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9BA8C4),
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${feat['title']} : ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF3EEE2),
                                    ),
                                  ),
                                  TextSpan(text: feat['body']),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (forceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C5C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF5C5C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFF5C5C), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cette mise à jour est requise pour continuer à utiliser l\'application.',
                            style: TextStyle(
                              color: Color(0xFFFF5C5C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Plus tard',
                style: TextStyle(color: Color(0xFF9BA8C4)),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => _handleDownload(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Télécharger'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3CC8E8),
              foregroundColor: const Color(0xFF060B1A),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
