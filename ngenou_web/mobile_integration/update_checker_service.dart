import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_dialog.dart';

/// URL publique de la page des nouveautés / téléchargement de l'APK
const String kNgenouUpdateUrl = 'https://ngenou.top/nouveautes';

/// Service de vérification des mises à jour pour l'application mobile Ngenou
class UpdateChecker {
  static const String _kLastCheckKey = 'ngenou_last_update_check_timestamp';

  /// Code de version installé par défaut si package_info_plus n'est pas utilisé
  static const int kCurrentVersionCode = 11;
  static const String kCurrentVersionName = '1.1.0';

  /// Vérification silencieuse au lancement de l'application (max 1 fois par jour)
  /// Ne bloque pas l'application et ignore les erreurs réseau en cas de mode hors-ligne.
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMs = prefs.getInt(_kLastCheckKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 24 heures = 86 400 000 ms
      const oneDayMs = 24 * 60 * 60 * 1000;
      if (nowMs - lastCheckMs < oneDayMs) {
        return; // Déjà vérifié aujourd'hui
      }

      await prefs.setInt(_kLastCheckKey, nowMs);
      if (!context.mounted) return;

      await checkForUpdate(
        context,
        isManual: false,
      );
    } catch (_) {
      // Ignorer silencieusement en cas d'absence de réseau au démarrage
    }
  }

  /// Vérifie si une mise à jour est disponible
  /// [isManual] : Si true (appel depuis Paramètres), affiche un message si l'app est à jour.
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isManual = false,
    int? currentInstalledCode,
  }) async {
    final installedCode = currentInstalledCode ?? kCurrentVersionCode;

    try {
      final client = Supabase.instance.client;

      // Récupérer la dernière version publiée
      final response = await client
          .from('app_releases')
          .select('*, release_features(*)')
          .eq('is_published', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (isManual && context.mounted) {
          _showSnackBar(context, 'Votre application Ngenou est à jour !');
        }
        return;
      }

      final remoteCode = (response['version_code'] as num?)?.toInt() ?? 0;
      final versionName = response['version_name'] as String? ?? '';
      final title = response['title'] as String? ?? 'Mise à jour disponible';
      final notes = response['notes'] as String? ?? '';
      final apkUrl = response['apk_url'] as String? ?? kNgenouUpdateUrl;
      final forceUpdate = response['force_update'] as bool? ?? false;

      final rawFeatures = response['release_features'] as List? ?? [];
      final features = rawFeatures.map((f) {
        return {
          'title': f['title']?.toString() ?? '',
          'body': f['body']?.toString() ?? '',
        };
      }).toList();

      // Comparaison : si version distante > version locale
      if (remoteCode > installedCode) {
        if (!context.mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (dialogContext) => UpdateDialog(
            versionName: versionName,
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
          _showSnackBar(context, 'Votre application Ngenou est à jour (v$kCurrentVersionName).');
        }
      }
    } catch (e) {
      if (isManual && context.mounted) {
        _showSnackBar(
          context,
          'Impossible de vérifier les mises à jour (vérifiez votre connexion Internet).',
          isError: true,
        );
      }
    }
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF5C5C) : const Color(0xFF2DD4BF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
