import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/update_dialog.dart';

/// Service centralisé de vérification et de gestion des mises à jour dynamiques
class AppUpdateService {
  static const String _kLastCheckKey = 'ngenou_last_update_check_timestamp';

  /// Version actuelle de l'application mobile (synchronisée avec pubspec.yaml)
  static const String currentVersionName = '1.1.1';
  static const int currentVersionCode = 1;

  /// Vérification silencieuse au lancement de l'application.
  /// S'exécute au maximum une fois toutes les 24 heures.
  /// En cas d'absence de réseau, échoue silencieusement sans perturber l'expérience utilisateur.
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMs = prefs.getInt(_kLastCheckKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      const oneDayMs = 24 * 60 * 60 * 1000;
      if (nowMs - lastCheckMs < oneDayMs) {
        return; // Déjà vérifié au cours des dernières 24h
      }

      await prefs.setInt(_kLastCheckKey, nowMs);
      if (!context.mounted) return;

      await checkForUpdate(context, isManual: false);
    } catch (e) {
      debugPrint('Silent update check skipped: $e');
    }
  }

  /// Vérifie si une nouvelle version est publiée sur Supabase.
  /// [isManual] : Si true (appelé depuis la page Paramètres), affiche un feedback explicite à l'utilisateur.
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isManual = false,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Récupérer la dernière version publiée avec ses fonctionnalités associées
      final response = await client
          .from('app_releases')
          .select('*, release_features(*)')
          .eq('is_published', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (isManual && context.mounted) {
          _showFeedback(
            context,
            'Votre application Ngenou est à jour (v$currentVersionName).',
            isSuccess: true,
          );
        }
        return;
      }

      final remoteCode = (response['version_code'] as num?)?.toInt() ?? 0;
      final remoteVersionName = response['version_name'] as String? ?? '';
      final title = response['title'] as String? ?? 'Nouvelle version disponible';
      final notes = response['notes'] as String? ?? '';
      final apkUrl = response['apk_url'] as String? ??
          'https://github.com/Francko0237/Ngenou_Web/releases/latest';
      final forceUpdate = response['force_update'] as bool? ?? false;

      final rawFeatures = response['release_features'] as List? ?? [];
      final features = rawFeatures.map<Map<String, String>>((f) {
        return {
          'title': f['title']?.toString() ?? '',
          'body': f['body']?.toString() ?? '',
          'image_url': f['image_url']?.toString() ?? '',
        };
      }).toList();

      // Si la version distante a un versionCode supérieur à la locale
      if (remoteCode > currentVersionCode) {
        if (!context.mounted) return;

        await showDialog<void>(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (dialogContext) => UpdateDialog(
            versionName: remoteVersionName.isNotEmpty ? remoteVersionName : 'v$remoteCode',
            versionCode: remoteCode,
            title: title,
            notes: notes,
            apkUrl: apkUrl,
            forceUpdate: forceUpdate,
            features: features,
          ),
        );
      } else {
        if (isManual && context.mounted) {
          _showFeedback(
            context,
            'Votre application Ngenou est à jour (v$currentVersionName).',
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      if (isManual && context.mounted) {
        _showFeedback(
          context,
          'Impossible de vérifier les mises à jour. Vérifiez votre connexion Internet.',
          isSuccess: false,
        );
      }
    }
  }

  static void _showFeedback(
    BuildContext context,
    String message, {
    required bool isSuccess,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
