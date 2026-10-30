import 'dart:convert';
import 'custom_course_package.dart';
import 'matiere.dart';

class TeacherCourseItem {
  final String id;
  final String teacherId;
  final String teacherName;
  final String matiereId;
  final String titre;
  final String description;
  final String schoolLevel; // primaire, college, lycee, superieur
  final String matiereNom;
  final String icone;
  final String couleur;
  final int durationMinutes;
  final Map<String, dynamic> jsonData;
  final String? classe;
  final String? coverImageUrl;
  final bool isPublished;
  final int downloadsCount;
  final DateTime? createdAt;

  TeacherCourseItem({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.matiereId,
    required this.titre,
    required this.description,
    required this.schoolLevel,
    required this.matiereNom,
    required this.icone,
    required this.couleur,
    required this.durationMinutes,
    required this.jsonData,
    this.classe,
    this.coverImageUrl,
    required this.isPublished,
    required this.downloadsCount,
    this.createdAt,
  });

  factory TeacherCourseItem.fromJson(Map<String, dynamic> map) {
    Map<String, dynamic> rawJson = {};
    final raw = map['json_data'];
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          rawJson = jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>;
        }
      } catch (_) {}
    } else if (raw is Map) {
      try {
        rawJson = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      } catch (_) {}
    }

    return TeacherCourseItem(
      id: map['id']?.toString() ?? '',
      teacherId: map['teacher_id']?.toString() ?? '',
      teacherName: map['teacher_name'] as String? ?? 'Enseignant',
      matiereId: map['matiere_id'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      description: map['description'] as String? ?? '',
      schoolLevel: map['school_level'] as String? ?? 'college',
      matiereNom: map['matiere_nom'] as String? ?? '',
      icone: map['icone'] as String? ?? 'book',
      couleur: map['couleur'] as String? ?? '#3498DB',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 120,
      jsonData: rawJson,
      classe: map['classe'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      isPublished: map['is_published'] as bool? ?? true,
      downloadsCount: (map['downloads_count'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  CustomCoursePackage toPackage() {
    CustomCoursePackage pkg;
    try {
      if (jsonData.isNotEmpty && jsonData['matiere'] != null) {
        pkg = CustomCoursePackage.fromJson(jsonData);
      } else {
        pkg = _createFallbackPackage();
      }
    } catch (_) {
      pkg = _createFallbackPackage();
    }

    final finalCover = (coverImageUrl != null &&
            coverImageUrl!.isNotEmpty &&
            (pkg.matiere.coverImageUrl == null ||
                pkg.matiere.coverImageUrl!.isEmpty))
        ? coverImageUrl
        : pkg.matiere.coverImageUrl;

    return CustomCoursePackage(
      schemaVersionValue: pkg.schemaVersionValue,
      meta: pkg.meta.copyWith(
        isPublic: true,
        authorName: teacherName.isNotEmpty ? teacherName : null,
        teacherId: teacherId,
      ),
      matiere: pkg.matiere.copyWith(coverImageUrl: finalCover),
      notions: pkg.notions,
      lecons: pkg.lecons,
      exercices: pkg.exercices,
    );
  }

  CustomCoursePackage _createFallbackPackage() {
    return CustomCoursePackage(
      schemaVersionValue: CustomCoursePackage.schemaVersion,
      meta: CourseMeta(
        objectif: description.isNotEmpty ? description : 'Apprendre et réviser',
        langue: 'Français',
        isPublic: true,
        authorName: teacherName.isNotEmpty ? teacherName : null,
        teacherId: teacherId,
      ),
      matiere: Matiere(
        id: matiereId.isNotEmpty ? matiereId : 'course_${DateTime.now().millisecondsSinceEpoch}',
        nom: titre.isNotEmpty ? titre : (matiereNom.isNotEmpty ? matiereNom : 'Cours'),
        description: description,
        icone: CustomCoursePackage.iconFromKey(icone),
        couleur: CustomCoursePackage.colorFromHex(couleur),
        isAvailable: true,
        durationMinutes: durationMinutes,
        coverImageUrl: coverImageUrl,
      ),
      notions: const [],
      lecons: const [],
      exercices: const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacher_id': teacherId,
    'teacher_name': teacherName,
    'matiere_id': matiereId,
    'titre': titre,
    'description': description,
    'school_level': schoolLevel,
    'classe': classe,
    'cover_image_url': coverImageUrl,
    'matiere_nom': matiereNom,
    'icone': icone,
    'couleur': couleur,
    'duration_minutes': durationMinutes,
    'json_data': jsonData,
    'is_published': isPublished,
    'downloads_count': downloadsCount,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
