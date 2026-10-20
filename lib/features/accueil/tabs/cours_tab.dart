import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/projet.dart';
import '../../../core/providers/custom_courses_provider.dart';
import '../../../core/providers/progression_provider.dart';
import '../../../core/providers/projets_provider.dart';
import '../../../core/providers/defis_provider.dart';
import '../../../modules/modules_registry.dart';
import '../widgets/matiere_card.dart';
import '../../projets/widgets/projet_card.dart';
import '../../projets/widgets/projet_context_menu.dart';
import '../../projets/create_project_wizard_page.dart';
import '../../projets/projet_detail_page.dart';
import '../widgets/first_steps_checklist_card.dart';

class CoursTab extends StatefulWidget {
  final String username;
  final String userRole;
  final int selectedSubTab; // 0 = Mes cours, 1 = Projets
  final ValueChanged<int> onSubTabChanged;
  final VoidCallback onRefresh;

  const CoursTab({
    super.key,
    required this.username,
    required this.userRole,
    required this.selectedSubTab,
    required this.onSubTabChanged,
    required this.onRefresh,
  });

  @override
  State<CoursTab> createState() => _CoursTabState();
}

class _CoursTabState extends State<CoursTab> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.selectedSubTab);
  }

  @override
  void didUpdateWidget(CoursTab old) {
    super.didUpdateWidget(old);
    // Si le parent change l'onglet (tap sur le toggle), on anime le PageView
    if (old.selectedSubTab != widget.selectedSubTab) {
      _pageController.animateToPage(
        widget.selectedSubTab,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final progProvider = context.watch<ProgressionProvider>();
    final projetsProvider = context.watch<ProjetsProvider>();
    final customProvider = context.watch<CustomCoursesProvider>();
    final defisProvider = context.watch<DefisProvider>();

    // Calcul des cours affichés (natives + custom hors projets)
    final allCustomIds = customProvider.modules.map((m) => m.matiere.id).toList();
    final inProjectIds = projetsProvider.projets.expand((p) => p.matiereIds).toSet();
    final horsProjetIds = allCustomIds.where((id) => !inProjectIds.contains(id)).toSet();

    final matieres = ModulesRegistry.matieres.where((m) {
      if (!m.id.startsWith('custom_')) return true;
      return horsProjetIds.contains(m.id);
    }).toList();

    // Calcul des mini-stats
    double totalProg = 0;
    int evaluatedCount = 0;
    for (final m in matieres) {
      final p = progProvider.getProgressionGlobale(m.id);
      if (p > 0) {
        totalProg += p;
        evaluatedCount++;
      }
    }
    final avgProg = matieres.isNotEmpty && evaluatedCount > 0
        ? (totalProg / matieres.length).clamp(0.0, 100.0)
        : 0.0;
    final streak = defisProvider.history.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hPad = w > 1200 ? w * 0.08 : w > 700 ? w * 0.05 : 18.0;
        final cols = w > 1100 ? 4 : w > 700 ? 3 : 2;
        // Ratio ajusté pour coller au contenu de MatiereCard (cover 55% + texte 45%)
        // sans laisser d'espace blanc en bas
        final ratio = w > 900 ? 1.15 : 0.95;

        return Column(
          children: [
            // ─── Partie fixe : salutation + stats + toggle ─────────────────
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salutation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour ${widget.username} 👋🏾 ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : const Color(0xFF15151C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Prêt pour votre apprentissage aujourd'hui ?",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.userRole == 'teacher')
                          GestureDetector(
                            onTap: () => context.push('/enseignant').then((_) => widget.onRefresh()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.co_present_rounded, size: 16, color: primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Espace Prof',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mini-Stats Bar
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStatCard(
                            icon: Icons.menu_book_rounded,
                            iconColor: const Color(0xFF3498DB),
                            value: '${matieres.length}',
                            label: 'Matières',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMiniStatCard(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF2ECC71),
                            value: '${avgProg.toStringAsFixed(0)}%',
                            label: 'Maîtrisé',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMiniStatCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFE67E22),
                            value: streak > 0 ? '$streak j' : 'Actif',
                            label: 'Série',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Guide interactif Premiers pas (onboarding dashboard)
                    FirstStepsChecklistCard(
                      onExploreCourses: () => widget.onSubTabChanged(0),
                    ),
                    const SizedBox(height: 18),

                    // Toggle Mes cours / Projets
                    Center(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(3.5),
                        child: LayoutBuilder(
                          builder: (context, boxConstraints) {
                            final indicatorWidth = boxConstraints.maxWidth / 2;
                            return Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  left: widget.selectedSubTab == 0 ? 0 : indicatorWidth,
                                  top: 0,
                                  bottom: 0,
                                  width: indicatorWidth,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF262630) : Colors.white,
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SubTabButton(
                                        label: 'Mes cours',
                                        icon: Icons.auto_stories_rounded,
                                        selected: widget.selectedSubTab == 0,
                                        primary: primary,
                                        isDark: isDark,
                                        onTap: () => widget.onSubTabChanged(0),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SubTabButton(
                                        label: 'Projets',
                                        icon: Icons.folder_special_rounded,
                                        selected: widget.selectedSubTab == 1,
                                        primary: primary,
                                        isDark: isDark,
                                        onTap: () => widget.onSubTabChanged(1),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            // ─── PageView swipeable ────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) {
                  // Notifie le parent pour que le toggle se mette à jour
                  widget.onSubTabChanged(index);
                },
                children: [
                  // Page 0 : Mes cours
                  _CoursPage(
                    matieres: matieres,
                    progProvider: progProvider,
                    hPad: hPad,
                    cols: cols,
                    ratio: ratio,
                    isDark: isDark,
                  ),
                  // Page 1 : Projets
                  _ProjetsPage(
                    projetsProvider: projetsProvider,
                    progProvider: progProvider,
                    hPad: hPad,
                    isDark: isDark,
                    onRefresh: widget.onRefresh,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF15151C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page Mes cours ────────────────────────────────────────────────────────────

class _CoursPage extends StatelessWidget {
  final List<dynamic> matieres;
  final ProgressionProvider progProvider;
  final double hPad;
  final int cols;
  final double ratio;
  final bool isDark;

  const _CoursPage({
    required this.matieres,
    required this.progProvider,
    required this.hPad,
    required this.cols,
    required this.ratio,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 80),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: ratio,
      ),
      itemCount: matieres.length,
      itemBuilder: (context, index) {
        final matiere = matieres[index];
        final prog = progProvider.getProgressionGlobale(matiere.id);
        final isCustom = ModulesRegistry.isCustomMatiere(matiere.id);
        final isPublic = ModulesRegistry.isPublicCourse(matiere.id);
        return MatiereCard(
          titre: matiere.nom,
          icon: matiere.icone,
          isAvailable: matiere.isAvailable,
          progression: prog,
          isCustom: isCustom,
          isPublic: isPublic,
          matiereId: matiere.id,
          coverImageUrl: matiere.coverImageUrl,
          couleur: matiere.couleur,
          onTap: () => context.push('/cours/${matiere.id}'),
        );
      },
    );
  }
}

// ── Page Projets ──────────────────────────────────────────────────────────────

class _ProjetsPage extends StatelessWidget {
  final ProjetsProvider projetsProvider;
  final ProgressionProvider progProvider;
  final double hPad;
  final bool isDark;
  final VoidCallback onRefresh;

  const _ProjetsPage({
    required this.projetsProvider,
    required this.progProvider,
    required this.hPad,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildCreateProjectCard(context),
        const SizedBox(height: 16),
        if (projetsProvider.projets.isEmpty)
          _buildEmptyProjetState()
        else
          ...projetsProvider.projets.asMap().entries.map((entry) {
            final i = entry.key;
            final projet = entry.value;
            final progression = projetsProvider.getProgressionProjet(
              projet,
              progProvider,
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < projetsProvider.projets.length - 1 ? 12 : 0,
              ),
              child: ProjetCard(
                projet: projet,
                progression: progression,
                onTap: () => _openProjet(context, projet),
                onLongPress: projet.isSystem
                    ? null
                    : () => showProjetContextMenu(
                          context,
                          projet: projet,
                          onRefresh: onRefresh,
                        ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCreateProjectCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final projetId = await Navigator.push<String?>(
          context,
          MaterialPageRoute(builder: (_) => const CreateProjectWizardPage()),
        );
        if (projetId != null) {
          final projet = context.read<ProjetsProvider>().getProjetById(projetId);
          if (projet != null && context.mounted) {
            _openProjet(context, projet);
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3D9EFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.create_new_folder_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouveau projet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "L'IA génère un programme de cours personnalisé",
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProjetState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 48,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun projet pour le moment',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Créez un projet pour organiser vos matières par objectif.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openProjet(BuildContext context, Projet projet) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjetDetailPage(projetId: projet.id)),
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? (isDark ? Colors.white : primary)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.white : primary)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
