import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/teacher_course_item.dart';
import '../../core/models/custom_course_package.dart';
import '../../core/services/teacher_courses_service.dart';
import '../../core/services/auth_service.dart';

class EnseignantDashboardPage extends StatefulWidget {
  const EnseignantDashboardPage({super.key});

  @override
  State<EnseignantDashboardPage> createState() => _EnseignantDashboardPageState();
}

class _EnseignantDashboardPageState extends State<EnseignantDashboardPage> {
  List<TeacherCourseItem> _myCourses = [];
  bool _isLoading = true;
  String _teacherName = 'Enseignant';

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    final name = await AuthService.getUsername();
    final courses = await TeacherCoursesService.fetchMyCourses();
    if (mounted) {
      setState(() {
        _teacherName = name;
        _myCourses = courses;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePublish(TeacherCourseItem course) async {
    final newStatus = !course.isPublished;
    await TeacherCoursesService.togglePublishStatus(course.id, course.isPublished);
    if (mounted) {
      setState(() {
        final index = _myCourses.indexWhere((c) => c.id == course.id);
        if (index != -1) {
          final updated = TeacherCourseItem(
            id: course.id,
            teacherId: course.teacherId,
            teacherName: course.teacherName,
            matiereId: course.matiereId,
            titre: course.titre,
            description: course.description,
            schoolLevel: course.schoolLevel,
            matiereNom: course.matiereNom,
            icone: course.icone,
            couleur: course.couleur,
            durationMinutes: course.durationMinutes,
            jsonData: course.jsonData,
            isPublished: newStatus,
            downloadsCount: course.downloadsCount,
            createdAt: course.createdAt,
          );
          _myCourses[index] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Cours publié sur le catalogue !'
                : 'Cours retiré du catalogue (mode brouillon).',
          ),
        ),
      );
    }
  }

  Future<void> _deleteCourse(TeacherCourseItem course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: Text(
          'Voulez-vous vraiment supprimer "${course.titre}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TeacherCoursesService.deleteCourse(course.id);
      _loadTeacherData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    final totalDownloads =
        _myCourses.fold<int>(0, (sum, c) => sum + c.downloadsCount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Espace Enseignant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadTeacherData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // En-tête de bienvenue
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_pin_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bonjour, Prof. $_teacherName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Gérez vos cours et vos partages pour vos élèves',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Mini stats
                        Row(
                          children: [
                            Expanded(
                              child: _statPill(
                                label: 'Cours créés',
                                value: '${_myCourses.length}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statPill(
                                label: 'Téléchargements',
                                value: '$totalDownloads',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions rapides
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: 'Créer un cours',
                          icon: Icons.add_circle_outline_rounded,
                          color: const Color(0xFF6C63FF),
                          isDark: isDark,
                          onTap: () => context.push('/course-builder'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          label: 'Voir le catalogue',
                          icon: Icons.public_rounded,
                          color: const Color(0xFF00B4D8),
                          isDark: isDark,
                          onTap: () => context.push('/catalogue'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Titre de section "Mes cours créés"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mes cours créés',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_myCourses.length} cours',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_myCourses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 56,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Vous n\'avez pas encore créé de cours',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Utilisez l\'assistant IA ou rédigez votre premier cours.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/course-builder'),
                              icon: const Icon(Icons.add),
                              label: const Text('Créer mon premier cours'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._myCourses.map((c) => _buildCourseItemCard(
                          course: c,
                          isDark: isDark,
                          primary: primary,
                        )),
                ],
              ),
            ),
    );
  }

  Widget _statPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseItemCard({
    required TeacherCourseItem course,
    required bool isDark,
    required Color primary,
  }) {
    final couleur = CustomCoursePackage.colorFromHex(course.couleur);
    final icone = CustomCoursePackage.iconFromKey(course.icone);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: course.coverImageUrl != null && course.coverImageUrl!.isNotEmpty
                    ? (course.coverImageUrl!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(course.coverImageUrl!.split(',').last),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(icone, color: couleur, size: 24),
                          )
                        : Image.network(
                            course.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(icone, color: couleur, size: 24),
                          ))
                    : Icon(icone, color: couleur, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.schoolLevel.toUpperCase()}${course.classe != null && course.classe!.trim().isNotEmpty ? " • ${course.classe!.trim()}" : ""} · ${course.downloadsCount} téléchargements',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu Options (Supprimer)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'delete') _deleteCourse(course);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Switch Publié / Brouillon
              Row(
                children: [
                  Switch(
                    value: course.isPublished,
                    activeThumbColor: const Color(0xFF2ECC71),
                    onChanged: (_) => _togglePublish(course),
                  ),
                  Text(
                    course.isPublished ? 'En ligne (Public)' : 'Brouillon (Masqué)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: course.isPublished
                          ? const Color(0xFF2ECC71)
                          : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ],
              ),
              // Bouton Tester
              TextButton.icon(
                onPressed: () => context.push('/cours/${course.matiereId}'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Tester'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
