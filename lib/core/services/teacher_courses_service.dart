import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custom_course_package.dart';
import '../models/teacher_course_item.dart';
import 'auth_service.dart';

class TeacherCoursesService {
  static final SupabaseClient _client = Supabase.instance.client;

  static List<TeacherCourseItem> _cachedCatalog = [];

  /// Récupère la liste des cours publiés pour le catalogue (avec timeout & cache hors-ligne)
  static Future<List<TeacherCourseItem>> fetchCatalog({
    String? schoolLevel,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('teacher_courses')
          .select()
          .eq('is_published', true);

      if (schoolLevel != null && schoolLevel.isNotEmpty && schoolLevel != 'all') {
        query = query.eq('school_level', schoolLevel);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('titre', '%${searchQuery.trim()}%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 7));

      final items = (response as List<dynamic>)
          .map((item) => TeacherCourseItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (items.isNotEmpty) {
        _cachedCatalog = items;
      }
      return items;
    } catch (e) {
      debugPrint("Erreur lors de la récupération du catalogue : $e");
      // Si une erreur réseau survient (hors-ligne / DNS), renvoyer le cache si disponible
      if (_cachedCatalog.isNotEmpty) {
        debugPrint("Retour du catalogue en cache hors-ligne (${_cachedCatalog.length} cours)");
        return _cachedCatalog;
      }
      rethrow;
    }
  }

  /// Récupère les cours créés par l'enseignant actuellement connecté
  static Future<List<TeacherCourseItem>> fetchMyCourses() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('teacher_courses')
          .select()
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => TeacherCourseItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Erreur récupération mes cours enseignant : $e");
      return [];
    }
  }

  /// Publie un cours créé par un enseignant
  static Future<TeacherCourseItem?> publishCourse({
    required CustomCoursePackage package,
    required String schoolLevel,
    String? classe,
    String? coverImageUrl,
    bool isPublished = true,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw Exception("Vous devez être connecté pour publier un cours.");
    }

    final teacherName = await AuthService.getUsername();
    final titre = package.matiere.nom.trim();

    // S'assurer que le niveau scolaire correspond aux contraintes de la base
    final validLevels = {'primaire', 'college', 'lycee', 'superieur'};
    final sanitizedLevel = validLevels.contains(schoolLevel.toLowerCase())
        ? schoolLevel.toLowerCase()
        : 'college';

    final payload = {
      'teacher_id': user.id,
      'teacher_name': teacherName,
      'matiere_id': package.matiere.id,
      'titre': titre,
      'description': package.matiere.description,
      'school_level': sanitizedLevel,
      if (classe != null && classe.trim().isNotEmpty) 'classe': classe.trim(),
      if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
        'cover_image_url': coverImageUrl.trim(),
      'matiere_nom': package.matiere.nom,
      'icone': CustomCoursePackage.iconToKey(package.matiere.icone),
      'couleur': CustomCoursePackage.colorToHex(package.matiere.couleur),
      'duration_minutes': package.matiere.durationMinutes,
      'json_data': package.toJson(),
      'is_published': isPublished,
    };

    final response = await _client
        .from('teacher_courses')
        .insert(payload)
        .select()
        .single();

    return TeacherCourseItem.fromJson(response);
  }

  /// Modifie la visibilité (publié / brouillon) d'un cours
  static Future<void> togglePublishStatus(String courseId, bool currentStatus) async {
    await _client
        .from('teacher_courses')
        .update({'is_published': !currentStatus})
        .eq('id', courseId);
  }

  /// Supprime un cours enseignant
  static Future<void> deleteCourse(String courseId) async {
    await _client
        .from('teacher_courses')
        .delete()
        .eq('id', courseId);
  }

  /// Incrémente le compteur de téléchargements d'un cours via RPC
  static Future<void> incrementDownloads(String courseId) async {
    try {
      await _client.rpc('increment_course_downloads', params: {
        'p_course_id': courseId,
      });
    } catch (e) {
      debugPrint("Erreur incrementDownloads : $e");
    }
  }
}
