import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/teacher_course_item.dart';
import '../../core/models/custom_course_package.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/services/teacher_courses_service.dart';

class CatalogueCoursesPage extends StatefulWidget {
  const CatalogueCoursesPage({super.key});

  @override
  State<CatalogueCoursesPage> createState() => _CatalogueCoursesPageState();
}

class _CatalogueCoursesPageState extends State<CatalogueCoursesPage> {
  String _selectedLevel = 'all'; // all, primaire, secondaire, superieur
  final TextEditingController _searchController = TextEditingController();
  List<TeacherCourseItem> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _downloadingCourseIds = {};

  final List<Map<String, String>> _levels = [
    {'key': 'all', 'label': 'Tous les niveaux'},
    {'key': 'primaire', 'label': 'Primaire'},
    {'key': 'secondaire', 'label': 'Secondaire'},
    {'key': 'superieur', 'label': 'Supérieur'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await TeacherCoursesService.fetchCatalog(
        schoolLevel: _selectedLevel == 'all' ? null : _selectedLevel,
        searchQuery: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _courses = results;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _courses = [];
          _isLoading = false;
          _errorMessage = "Impossible de contacter le serveur.\nVérifiez la connexion Internet de votre appareil.";
        });
      }
    }
  }

  Future<void> _downloadCourse(TeacherCourseItem course) async {
    final customProvider = context.read<CustomCoursesProvider>();
    final isAlreadyInstalled =
        customProvider.modules.any((m) => m.matiere.id == course.matiereId);

    if (isAlreadyInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce cours est déjà installé sur votre appareil.')),
      );
      return;
    }

    setState(() => _downloadingCourseIds.add(course.id));

    try {
      TeacherCoursesService.markAsPublic(course.matiereId);
      final package = course.toPackage();
      await customProvider.importCourse(package);
      await TeacherCoursesService.incrementDownloads(course.id);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2ECC71),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              content: Text('Cours "${course.titre}" téléchargé avec succès !'),
              action: SnackBarAction(
                label: 'Ouvrir',
                textColor: Colors.white,
                onPressed: () => context.push('/cours/${course.matiereId}'),
              ),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erreur lors du téléchargement : $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingCourseIds.remove(course.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final customProvider = context.watch<CustomCoursesProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Cours publics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadCatalog(),
              decoration: InputDecoration(
                hintText: 'Rechercher un cours...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadCatalog();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
          ),

          // Filtres par niveau scolaire
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _levels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final lvl = _levels[i];
                final isSelected = _selectedLevel == lvl['key'];
                return ChoiceChip(
                  label: Text(lvl['label']!),
                  selected: isSelected,
                  selectedColor: primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedLevel = lvl['key']!);
                      _loadCatalog();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Liste des cours
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.wifi_off_rounded,
                                  size: 48,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadCatalog,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Réessayer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _courses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun cours trouvé dans ce cycle',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Les cours publiés par les enseignants apparaîtront ici.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white38 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          )
                    : RefreshIndicator(
                        onRefresh: _loadCatalog,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            // Responsive : 1 col mobile, 2 tablette, 3 desktop, 4 large
                            final cols = w > 1400 ? 4 : w > 1050 ? 3 : w > 650 ? 2 : 1;
                            final hPad = w > 1200
                                ? w * 0.08
                                : w > 800
                                    ? w * 0.05
                                    : 16.0;

                            if (cols == 1) {
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: hPad,
                                  vertical: 12,
                                ),
                                itemCount: _courses.length,
                                itemBuilder: (context, index) {
                                  final course = _courses[index];
                                  final isInstalled = customProvider.modules
                                      .any((m) => m.matiere.id == course.matiereId);
                                  final isDownloading =
                                      _downloadingCourseIds.contains(course.id);
                                  return _buildCourseCard(
                                    course: course,
                                    isDark: isDark,
                                    primary: primary,
                                    isInstalled: isInstalled,
                                    isDownloading: isDownloading,
                                    isGrid: false,
                                  );
                                },
                              );
                            }

                            final colWidth =
                                (w - (2 * hPad) - ((cols - 1) * 16)) / cols;
                            // Hauteur ciblée pour éviter tout espace blanc en bas
                            const targetHeight = 365.0;
                            final childAspectRatio =
                                (colWidth / targetHeight).clamp(0.60, 2.0);

                            return GridView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: hPad,
                                vertical: 16,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: _courses.length,
                              itemBuilder: (context, index) {
                                final course = _courses[index];
                                final isInstalled = customProvider.modules
                                    .any((m) => m.matiere.id == course.matiereId);
                                final isDownloading =
                                    _downloadingCourseIds.contains(course.id);
                                return _buildCourseCard(
                                  course: course,
                                  isDark: isDark,
                                  primary: primary,
                                  isInstalled: isInstalled,
                                  isDownloading: isDownloading,
                                  isGrid: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required TeacherCourseItem course,
    required bool isDark,
    required Color primary,
    required bool isInstalled,
    required bool isDownloading,
    required bool isGrid,
  }) {
    final couleur = CustomCoursePackage.colorFromHex(course.couleur);
    final icone = CustomCoursePackage.iconFromKey(course.icone);

    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre du cours
        Text(
          course.titre,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Enseignant créateur
        Row(
          children: [
            CircleAvatar(
              radius: 9,
              backgroundColor: primary.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 12, color: primary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Par ${course.teacherName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.verified, size: 13, color: Color(0xFF3498DB)),
          ],
        ),
        const SizedBox(height: 6),

        // Description
        if (course.description.isNotEmpty) ...[
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
        ],

        if (isGrid) const Spacer() else const SizedBox(height: 10),

        // Métriques : Durée & Téléchargements
        Row(
          children: [
            _buildStatPill(
              icon: Icons.schedule_rounded,
              label: '${course.durationMinutes} min',
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildStatPill(
              icon: Icons.download_done_rounded,
              label: '${course.downloadsCount} téléchargements',
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bouton d'action
        SizedBox(
          width: double.infinity,
          height: 44,
          child: isInstalled
              ? OutlinedButton.icon(
                  onPressed: () => context.push('/cours/${course.matiereId}'),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    'Déjà installé — Ouvrir le cours',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2ECC71),
                    side: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: isDownloading ? null : () => _downloadCourse(course),
                  icon: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    isDownloading
                        ? 'Téléchargement...'
                        : 'Télécharger le cours (Gratuit)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo de couverture / Header visuel façon produit ─────────────────
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCourseCover(course: course, couleur: couleur, icone: icone, isDark: isDark),
                // Gradient overlay en bas de la couverture
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
                // Badges en haut à gauche : Cycle & Classe
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      _buildHeaderTag(
                        label: course.schoolLevel.toUpperCase(),
                        color: const Color(0xFFE67E22),
                      ),
                      if (course.classe != null && course.classe!.trim().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildHeaderTag(
                          label: course.classe!.trim(),
                          color: const Color(0xFF2980B9),
                        ),
                      ],
                    ],
                  ),
                ),
                // Badge en haut à droite : Public / Gratuit
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Public',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Titre de matière sur l'image en bas
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icone, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.matiereNom,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Corps de la carte ───────────────────────────────────────────────
          if (isGrid)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: bodyContent,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: bodyContent,
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCover({
    required TeacherCourseItem course,
    required Color couleur,
    required IconData icone,
    required bool isDark,
  }) {
    final cover = course.coverImageUrl;
    if (cover != null && cover.isNotEmpty) {
      if (cover.startsWith('data:image')) {
        try {
          final commaIdx = cover.indexOf(',');
          final base64Str = commaIdx != -1 ? cover.substring(commaIdx + 1) : cover;
          final bytes = base64Decode(base64Str);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      } else if (cover.startsWith('http')) {
        return Image.network(
          cover,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackGradient(couleur, icone),
        );
      } else if (cover.startsWith('assets/')) {
        return Image.asset(cover, fit: BoxFit.cover);
      } else {
        return Image.file(
          File(cover),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackGradient(couleur, icone),
        );
      }
    }

    return _buildFallbackGradient(couleur, icone);
  }

  Widget _buildFallbackGradient(Color couleur, IconData icone) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            couleur,
            couleur.withValues(alpha: 0.65),
            const Color(0xFF1E1E2E),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icone,
          size: 64,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  Widget _buildHeaderTag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
