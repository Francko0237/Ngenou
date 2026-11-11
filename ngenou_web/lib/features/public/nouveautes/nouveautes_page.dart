import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_release.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/download_button.dart';
import '../../../core/widgets/phone_mockup.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/site_footer.dart';
import '../../../core/widgets/site_navbar.dart';

/// Page d'historique des versions et nouveautés de Ngenou (/nouveautes)
class NouveautesPage extends ConsumerWidget {
  const NouveautesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(publishedReleasesProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SiteNavbar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero d'en-tête
            Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 40 : 64,
                horizontal: Responsive.horizontalPadding(context),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF070E20),
                border: Border(
                  bottom: BorderSide(color: AppColors.cardBorder, width: 1),
                ),
              ),
              child: ResponsiveContainer(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              color: AppColors.cyan, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Changelog & Historique',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Toutes les nouveautés de Ngenou',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontSize: isMobile ? 32 : 44,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Découvrez au fil des mises à jour les nouvelles fonctionnalités pédagogiques et améliorations apportées à l\'application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Liste des versions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: ResponsiveContainer(
                maxWidth: 900,
                child: releasesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60.0),
                      child: CircularProgressIndicator(color: AppColors.cyan),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Impossible de charger les mises à jour : $error',
                            style: const TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (releases) {
                    if (releases.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  color: AppColors.textMuted, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Aucune version publiée pour le moment.',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(releases.length, (index) {
                        final release = releases[index];
                        final isLatest = index == 0;
                        return _ReleaseCard(
                          release: release,
                          isLatest: isLatest,
                        );
                      }),
                    );
                  },
                ),
              ),
            ),

            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final AppRelease release;
  final bool isLatest;

  const _ReleaseCard({
    required this.release,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    String dateStr = 'Récemment';
    if (release.publishedAt != null) {
      try {
        dateStr = DateFormat('d MMMM yyyy', 'fr_FR').format(release.publishedAt!);
      } catch (_) {
        final d = release.publishedAt!;
        dateStr = '${d.day}/${d.month}/${d.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLatest ? AppColors.cyan.withValues(alpha: 0.6) : AppColors.cardBorder,
          width: isLatest ? 1.5 : 1,
        ),
        boxShadow: isLatest
            ? [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de version
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Version ${release.versionName}',
                        style: const TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Dernière version',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (release.forceUpdate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Mise à jour obligatoire',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  release.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  release.notes,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          // Fonctionnalités de cette version
          if (release.features.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fonctionnalités & Améliorations',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...release.features.map((feature) {
                    final hasImage =
                        feature.imageUrl != null && feature.imageUrl!.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070E20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.cyan,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      feature.title,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      feature.body,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasImage) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: PhoneMockup(
                                imagePath: feature.imageUrl!,
                                isNetwork: feature.imageUrl!.startsWith('http'),
                                width: 220,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Action de téléchargement de l'APK de cette version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF091124),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: AppColors.cardBorder, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fichier d\'installation Android',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                DownloadButton(
                  isCompact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
