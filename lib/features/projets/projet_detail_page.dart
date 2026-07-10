import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/projet.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../modules/modules_registry.dart';
import '../course_builder/course_builder_wizard_page.dart';
import 'widgets/cours_context_menu.dart';
import '../../core/utils/duration_utils.dart';

class ProjetDetailPage extends StatefulWidget {
  final String projetId;

  const ProjetDetailPage({super.key, required this.projetId});

  @override
  State<ProjetDetailPage> createState() => _ProjetDetailPageState();
}

class _ProjetDetailPageState extends State<ProjetDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressAnim.forward();
    });
  }

  @override
  void dispose() {
    _progressAnim.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final projetsProvider = context.watch<ProjetsProvider>();
    final progProvider = context.watch<ProgressionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final projet = projetsProvider.getProjetById(widget.projetId);
    if (projet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projet introuvable')),
        body: const Center(child: Text('Ce projet n\'existe plus.')),
      );
    }

    final color = Projet.colorFromHex(projet.couleur);
    final progression =
        projetsProvider.getProgressionProjet(projet, progProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── AppBar avec header coloré ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: color,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HSLColor.fromColor(color)
                          .withLightness(
                            (HSLColor.fromColor(color).lightness + 0.1)
                                .clamp(0, 1),
                          )
                          .toColor(),
                      color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Projet.iconFromKey(projet.icone),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  projet.nom,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((projet.objectif ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              projet.objectif!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Contenu principal ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte de progression globale
                  _buildProgressCard(context, progression, projet, color, isDark),
                  const SizedBox(height: 28),
                  // En-tête de la liste des cours
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cours du projet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${projet.matiereIds.length} cours',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Liste des cours ──────────────────────────────────────────────
          if (projet.matiereIds.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildEmptyState(isDark),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final matiereId = projet.matiereIds[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    child: _buildCourseCard(
                      context,
                      matiereId,
                      projet,
                      progProvider,
                      color,
                      isDark,
                    ),
                  );
                },
                childCount: projet.matiereIds.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCours(context, projet),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un cours',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    double progression,
    Projet projet,
    Color color,
    bool isDark,
  ) {
    // Calcule la durée totale cumulée des matières du projet
    final totalMinutes = projet.matiereIds.fold<int>(
      0,
      (sum, id) => sum + (ModulesRegistry.getMatiere(id)?.durationMinutes ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cercle de progression animé
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) {
              final animated = _progressAnim.value * progression;
              return SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: animated / 100,
                      strokeWidth: 8,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    Text(
                      '${animated.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progression globale',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${projet.matiereIds.length} cours · '
                  '${progression == 100 ? "Terminé 🎉" : progression > 0 ? "En cours" : "Non commencé"}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (totalMinutes > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Durée totale : ${DurationUtils.format(totalMinutes)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) => LinearProgressIndicator(
                      value: (_progressAnim.value * progression) / 100,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progression == 100 ? Colors.amber : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    String matiereId,
    Projet projet,
    ProgressionProvider progProvider,
    Color projetColor,
    bool isDark,
  ) {
    final matiere = ModulesRegistry.getMatiere(matiereId);
    if (matiere == null) return const SizedBox.shrink();
    final prog = progProvider.getProgressionGlobale(matiereId);

    return GestureDetector(
      onLongPress: () => showCoursContextMenu(
        context,
        matiereId: matiereId,
        projetId: widget.projetId,
        onRefresh: _refresh,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/cours/$matiereId'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: projetColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(matiere.icone, color: projetColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matiere.nom,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (matiere.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            matiere.description,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 12,
                                color: projetColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              DurationUtils.format(matiere.durationMinutes),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: prog / 100,
                                  minHeight: 5,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    prog == 100 ? Colors.amber : projetColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${prog.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: prog == 100
                                    ? Colors.amber
                                    : projetColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              size: 56, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun cours dans ce projet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur le bouton "Ajouter un cours" pour créer votre premier cours.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addCours(BuildContext context, Projet projet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CourseBuilderWizardPage(projetId: widget.projetId),
      ),
    );
  }
}
