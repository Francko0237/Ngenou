import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_release.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_layout.dart';

/// Tableau de bord administrateur (/admin)
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortByDateDesc = true;
  String _filterStatus = 'all'; // 'all', 'published', 'draft'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signOut();
    if (mounted) {
      context.go('/admin/login');
    }
  }

  Future<void> _handleDelete(AppRelease release) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Confirmer la suppression', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Êtes-vous certain de vouloir supprimer définitivement la version ${release.versionName} (${release.title}) ?\n\nCette action est irréversible et supprimera également toutes ses fonctionnalités associées.',
          style: const TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(releaseRepositoryProvider);
        await repo.deleteRelease(release.id);
        ref.invalidate(adminReleasesProvider);
        ref.invalidate(publishedReleasesProvider);
        ref.invalidate(latestReleaseProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Version ${release.versionName} supprimée avec succès.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression : $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleTogglePublish(AppRelease release) async {
    final newStatus = !release.isPublished;
    try {
      final repo = ref.read(releaseRepositoryProvider);
      await repo.togglePublish(release.id, newStatus);
      ref.invalidate(adminReleasesProvider);
      ref.invalidate(publishedReleasesProvider);
      ref.invalidate(latestReleaseProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Version ${release.versionName} publiée en ligne !'
                  : 'Version ${release.versionName} retirée (mise en brouillon).',
            ),
            backgroundColor: AppColors.cyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(adminReleasesProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Console Admin Ngenou',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voir le site public',
            icon: const Icon(Icons.open_in_new_rounded, color: AppColors.cyan, size: 20),
            onPressed: () => context.go('/'),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/releases/new'),
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nouvelle version',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: 32,
        ),
        child: ResponsiveContainer(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre supérieure: Statistiques & Actions
              releasesAsync.when(
                data: (releases) => _buildStatsRow(releases, isMobile),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),

              // Barre d'outils: Recherche & Filtres
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Recherche
                    SizedBox(
                      width: isMobile ? double.infinity : 320,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Rechercher une version ou un titre...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.textMuted, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    // Filtres Statut & Tri
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'all',
                              label: Text('Toutes'),
                            ),
                            ButtonSegment(
                              value: 'published',
                              label: Text('Publiées'),
                            ),
                            ButtonSegment(
                              value: 'draft',
                              label: Text('Brouillons'),
                            ),
                          ],
                          selected: {_filterStatus},
                          onSelectionChanged: (val) {
                            setState(() => _filterStatus = val.first);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.cyan.withValues(alpha: 0.2);
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.cyan;
                              }
                              return AppColors.textMuted;
                            }),
                          ),
                        ),
                        IconButton(
                          tooltip: _sortByDateDesc
                              ? 'Tri : du plus récent au plus ancien'
                              : 'Tri : du plus ancien au plus récent',
                          icon: Icon(
                            _sortByDateDesc
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: AppColors.cyan,
                          ),
                          onPressed: () {
                            setState(() => _sortByDateDesc = !_sortByDateDesc);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Contenu principal de la liste
              releasesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60.0),
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  ),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text('Erreur de chargement : $e',
                      style: const TextStyle(color: AppColors.error)),
                ),
                data: (releases) {
                  // Filtrer et trier
                  var filtered = releases.where((r) {
                    final matchesQuery = _searchQuery.isEmpty ||
                        r.versionName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        r.notes.toLowerCase().contains(_searchQuery.toLowerCase());

                    if (!matchesQuery) return false;

                    if (_filterStatus == 'published') return r.isPublished;
                    if (_filterStatus == 'draft') return !r.isPublished;
                    return true;
                  }).toList();

                  filtered.sort((a, b) {
                    final comp = a.versionCode.compareTo(b.versionCode);
                    return _sortByDateDesc ? -comp : comp;
                  });

                  if (filtered.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune version trouvée avec ces critères.',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/admin/releases/new'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Créer une première version'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((release) {
                      return _buildReleaseItem(release, isMobile);
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<AppRelease> releases, bool isMobile) {
    final publishedCount = releases.where((r) => r.isPublished).length;
    final draftCount = releases.where((r) => !r.isPublished).length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Total des versions',
          value: releases.length.toString(),
          icon: Icons.layers_rounded,
          accent: AppColors.cyan,
          isMobile: isMobile,
        ),
        _buildStatCard(
          title: 'Versions publiées',
          value: publishedCount.toString(),
          icon: Icons.cloud_done_rounded,
          accent: AppColors.success,
          isMobile: isMobile,
        ),
        _buildStatCard(
          title: 'Brouillons en attente',
          value: draftCount.toString(),
          icon: Icons.edit_note_rounded,
          accent: AppColors.gold,
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseItem(AppRelease release, bool isMobile) {
    String dateStr = 'Non publiée';
    if (release.publishedAt != null) {
      try {
        dateStr = DateFormat('d MMM yyyy', 'fr_FR').format(release.publishedAt!);
      } catch (_) {
        final d = release.publishedAt!;
        dateStr = '${d.day}/${d.month}/${d.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: release.isPublished
              ? AppColors.cardBorder
              : AppColors.gold.withValues(alpha: 0.3),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReleaseHeader(release, dateStr),
                const SizedBox(height: 16),
                _buildReleaseActions(release),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildReleaseHeader(release, dateStr)),
                const SizedBox(width: 24),
                _buildReleaseActions(release),
              ],
            ),
    );
  }

  Widget _buildReleaseHeader(AppRelease release, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: release.isPublished
                    ? AppColors.cyan.withValues(alpha: 0.15)
                    : AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: release.isPublished
                      ? AppColors.cyan.withValues(alpha: 0.4)
                      : AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'v${release.versionName} (code: ${release.versionCode})',
                style: TextStyle(
                  color: release.isPublished ? AppColors.cyan : AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: release.isPublished
                    ? AppColors.success.withValues(alpha: 0.15)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                release.isPublished ? 'Publiée' : 'Brouillon',
                style: TextStyle(
                  color: release.isPublished ? AppColors.success : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (release.forceUpdate) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Obligatoire',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              dateStr,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          release.title,
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          release.notes,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.extension_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              '${release.features.length} fonctionnalité(s)',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (release.apkUrl != null && release.apkUrl!.isNotEmpty) ...[
              const SizedBox(width: 16),
              const Icon(Icons.link_rounded, size: 14, color: AppColors.cyan),
              const SizedBox(width: 4),
              const Text(
                'APK disponible',
                style: TextStyle(color: AppColors.cyan, fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReleaseActions(AppRelease release) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton Publier / Dépublier
        IconButton(
          tooltip: release.isPublished ? 'Dépublier (rendre brouillon)' : 'Publier en ligne',
          icon: Icon(
            release.isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded,
            color: release.isPublished ? AppColors.gold : AppColors.success,
          ),
          onPressed: () => _handleTogglePublish(release),
        ),
        // Bouton Modifier
        IconButton(
          tooltip: 'Modifier cette version',
          icon: const Icon(Icons.edit_outlined, color: AppColors.cyan),
          onPressed: () => context.go('/admin/releases/${release.id}/edit'),
        ),
        // Bouton Supprimer
        IconButton(
          tooltip: 'Supprimer définitivement',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          onPressed: () => _handleDelete(release),
        ),
      ],
    );
  }
}
