import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/teacher_course_item.dart';
import '../../core/models/custom_course_package.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/services/teacher_courses_service.dart';

// ── Constantes visuelles ──────────────────────────────────────────────────────
const _kBgDark = Color(0xFF121216);
const _kBgLight = Color(0xFFF7F8FA);
const _kSurfaceDark = Color(0xFF1E1E26);

class CatalogueCoursesPage extends StatefulWidget {
  const CatalogueCoursesPage({super.key});

  @override
  State<CatalogueCoursesPage> createState() => _CatalogueCoursesPageState();
}

class _CatalogueCoursesPageState extends State<CatalogueCoursesPage> {
  String _selectedLevel = 'all';
  final TextEditingController _searchController = TextEditingController();
  List<TeacherCourseItem> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _downloadingCourseIds = {};

  final List<_LevelFilter> _levels = const [
    _LevelFilter('all', 'Tous les niveaux'),
    _LevelFilter('primaire', 'Primaire'),
    _LevelFilter('secondaire', 'Secondaire'),
    _LevelFilter('superieur', 'Supérieur'),
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _courses = [];
          _isLoading = false;
          _errorMessage =
              "Impossible de contacter le serveur.\nVérifiez votre connexion Internet.";
        });
      }
    }
  }

  Future<void> _downloadCourse(TeacherCourseItem course) async {
    final customProvider = context.read<CustomCoursesProvider>();
    if (customProvider.modules.any((m) => m.matiere.id == course.matiereId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce cours est déjà installé sur votre appareil.'),
        ),
      );
      return;
    }
    setState(() => _downloadingCourseIds.add(course.id));
    try {
      TeacherCoursesService.markAsPublic(course.matiereId);
      final package = course.toPackage();
      final err = await customProvider.importCourse(package);
      if (err != null) {
        throw Exception(err);
      }
      await TeacherCoursesService.incrementDownloads(course.id);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        final ctrl = messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            dismissDirection: DismissDirection.horizontal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text('Cours "${course.titre}" téléchargé avec succès !'),
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () => context.push('/cours/${course.matiereId}'),
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 4), ctrl.close);
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
      if (mounted) setState(() => _downloadingCourseIds.remove(course.id));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final provider = context.watch<CustomCoursesProvider>();

    return Scaffold(
      backgroundColor: isDark ? _kBgDark : _kBgLight,
      appBar: AppBar(
        title: const Text(
          'Cours publics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadCatalog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Barre de recherche + Filtres ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                children: [
                  // Champ de recherche
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? _kSurfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _loadCatalog(),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un cours…',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white38 : Colors.black38,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadCatalog();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filtres de niveau
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _levels.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final lvl = _levels[i];
                        final sel = _selectedLevel == lvl.key;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedLevel = lvl.key);
                            _loadCatalog();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? primary
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.07)
                                        : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? primary
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(
                                              alpha: 0.08,
                                            )),
                              ),
                            ),
                            child: Text(
                              lvl.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: sel
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenu ─────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _ErrorState(
                          message: _errorMessage!,
                          primary: primary,
                          isDark: isDark,
                          onRetry: _loadCatalog,
                        )
                      : _courses.isEmpty
                          ? _EmptyState(isDark: isDark)
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final cols = w > 1400
                                    ? 4
                                    : w > 1050
                                    ? 3
                                    : w > 650
                                    ? 2
                                    : 1;
                                final hPad = w > 1200
                                    ? w * 0.08
                                    : w > 800
                                    ? w * 0.05
                                    : 16.0;

                                if (cols == 1) {
                                  return ListView.builder(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: hPad,
                                      vertical: 6,
                                    ),
                                    itemCount: _courses.length,
                                    itemBuilder: (context, i) {
                                      final c = _courses[i];
                                      final isInstalled = provider.modules.any(
                                        (m) => m.matiere.id == c.matiereId,
                                      );
                                      final isDownloading =
                                          _downloadingCourseIds.contains(c.id);
                                      return _CourseCard(
                                        course: c,
                                        isDark: isDark,
                                        primary: primary,
                                        isInstalled: isInstalled,
                                        isDownloading: isDownloading,
                                        isGrid: false,
                                        onDownload: () => _downloadCourse(c),
                                        onOpen: () => context.push('/cours/${c.matiereId}'),
                                      );
                                    },
                                  );
                                }

                                final colW = (w - 2 * hPad - (cols - 1) * 14.0) / cols;
                                final ratio = (colW / 365.0).clamp(0.60, 2.0);

                                return GridView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hPad,
                                    vertical: 6,
                                  ),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: ratio,
                                  ),
                                  itemCount: _courses.length,
                                  itemBuilder: (context, i) {
                                    final c = _courses[i];
                                    final isInstalled = provider.modules.any(
                                      (m) => m.matiere.id == c.matiereId,
                                    );
                                    final isDownloading =
                                        _downloadingCourseIds.contains(c.id);
                                    return _CourseCard(
                                      course: c,
                                      isDark: isDark,
                                      primary: primary,
                                      isInstalled: isInstalled,
                                      isDownloading: isDownloading,
                                      isGrid: true,
                                      onDownload: () => _downloadCourse(c),
                                      onOpen: () => context.push('/cours/${c.matiereId}'),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card cours ────────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final TeacherCourseItem course;
  final bool isDark, isInstalled, isDownloading, isGrid;
  final Color primary;
  final VoidCallback onDownload, onOpen;

  const _CourseCard({
    required this.course,
    required this.isDark,
    required this.primary,
    required this.isInstalled,
    required this.isDownloading,
    required this.isGrid,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = CustomCoursePackage.colorFromHex(course.couleur);
    final icone = CustomCoursePackage.iconFromKey(course.icone);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          course.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        // Enseignant
        Row(
          children: [
            CircleAvatar(
              radius: 8,
              backgroundColor: primary.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 10, color: primary),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Par ${course.teacherName}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            const Icon(
              Icons.verified_rounded,
              size: 12,
              color: Color(0xFF3498DB),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Description
        if (course.description.isNotEmpty) ...[
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (isGrid) const Spacer() else const SizedBox(height: 8),
        // Stats
        Row(
          children: [
            _Pill(
              icon: Icons.schedule_rounded,
              label: '${course.durationMinutes} min',
              isDark: isDark,
            ),
            const SizedBox(width: 7),
            _Pill(
              icon: Icons.download_done_rounded,
              label: '${course.downloadsCount}',
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Bouton
        SizedBox(
          width: double.infinity,
          height: 42,
          child: isInstalled
              ? OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text(
                    'Installé — Ouvrir',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2ECC71),
                    side: const BorderSide(
                      color: Color(0xFF2ECC71),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              : FilledButton.icon(
                  onPressed: isDownloading ? null : onDownload,
                  icon: isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    isDownloading ? 'En cours…' : 'Télécharger',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      ],
    );

    return InkWell(
      onTap: isInstalled ? onOpen : (isDownloading ? null : onDownload),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? _kSurfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover 120px
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(course: course, couleur: couleur, icone: icone),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badges niveau + classe
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        _Tag(
                          label: course.schoolLevel.toUpperCase(),
                          color: const Color(0xFFE67E22),
                        ),
                        if (course.classe != null &&
                            course.classe!.trim().isNotEmpty) ...[
                          const SizedBox(width: 5),
                          _Tag(
                            label: course.classe!.trim(),
                            color: const Color(0xFF2980B9),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Badge Public
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'Public',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Matière en bas
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icone, size: 13, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            course.matiereNom.isNotEmpty
                                ? course.matiereNom
                                : course.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Corps
            if (isGrid)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: body,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: body,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Cover image ───────────────────────────────────────────────────────────────

class _Cover extends StatelessWidget {
  final TeacherCourseItem course;
  final Color couleur;
  final IconData icone;

  const _Cover({
    required this.course,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final url = course.coverImageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final ci = url.indexOf(',');
          return Image.memory(
            base64Decode(ci != -1 ? url.substring(ci + 1) : url),
            fit: BoxFit.cover,
          );
        } catch (_) {}
      } else if (url.startsWith('http')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } else if (url.startsWith('assets/')) {
        return Image.asset(url, fit: BoxFit.cover);
      } else {
        return Image.file(
          File(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          couleur,
          couleur.withValues(alpha: 0.6),
          const Color(0xFF1E1E2E),
        ],
      ),
    ),
    child: Center(
      child: Icon(icone, size: 52, color: Colors.white.withValues(alpha: 0.22)),
    ),
  );
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _LevelFilter {
  final String key, label;
  const _LevelFilter(this.key, this.label);
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(7),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 3),
      ],
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _Pill({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Color primary;
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.primary,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            size: 44,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Réessayer',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.menu_book_rounded,
          size: 38,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.55),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Aucun cours trouvé',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Les cours publiés par les enseignants apparaîtront ici.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    ],
  );
}
