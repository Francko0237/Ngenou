import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_release.dart';
import '../supabase/providers.dart';
import '../theme/app_colors.dart';

/// Bouton de téléchargement de l'APK Ngenou
class DownloadButton extends ConsumerWidget {
  final bool isCompact;
  final VoidCallback? onDownloaded;

  const DownloadButton({
    super.key,
    this.isCompact = false,
    this.onDownloaded,
  });

  Future<void> _launchDownload(BuildContext context, AppRelease? release) async {
    final apkUrl = release?.apkUrl?.isNotEmpty == true
        ? release!.apkUrl!
        : 'Ngenou.apk';

    final uri = Uri.parse(apkUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir le lien : $apkUrl'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestReleaseAsync = ref.watch(latestReleaseProvider);
    final release = latestReleaseAsync.value;

    if (isCompact) {
      return ElevatedButton.icon(
        onPressed: () => _launchDownload(context, release),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Télécharger'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    String releaseMeta = 'Version Android';
    if (release != null) {
      String dateStr = 'Dernière version';
      if (release.publishedAt != null) {
        try {
          dateStr = DateFormat('d MMMM yyyy', 'fr_FR').format(release.publishedAt!);
        } catch (_) {
          final d = release.publishedAt!;
          dateStr = '${d.day}/${d.month}/${d.year}';
        }
      }
      releaseMeta = 'v${release.versionName} • $dateStr';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _launchDownload(context, release),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.android_rounded,
                    color: AppColors.background,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Application Android (APK)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.background.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Text(
                      'Télécharger Ngenou',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.background,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.background,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            releaseMeta,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
