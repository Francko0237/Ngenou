import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custom_course_package.dart';
import '../models/teacher_course_item.dart';
import 'auth_service.dart';

class TeacherCoursesService {
  static final SupabaseClient _client = Supabase.instance.client;

  static List<TeacherCourseItem> _cachedCatalog = [];
  static final Set<String> _publicMatiereIds = {};
  static bool _hasLoadedPersistedPublicIds = false;

  /// Vérifie si une matière provient du catalogue public
  static bool isPublicMatiere(String matiereId) {
    if (_publicMatiereIds.contains(matiereId)) return true;
    if (_cachedCatalog.any((c) => c.matiereId == matiereId)) return true;
    return false;
  }

  /// Enregistre une matière comme étant publique
  static void markAsPublic(String matiereId) {
    _publicMatiereIds.add(matiereId);
    _savePublicMatiereIds();
  }

  /// Charge les identifiants de matières publiques persistés localement
  static Future<void> loadPublicMatiereIds() async {
    if (_hasLoadedPersistedPublicIds) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('ngenou_public_matiere_ids') ?? [];
      _publicMatiereIds.addAll(list);
      _hasLoadedPersistedPublicIds = true;
    } catch (e) {
      debugPrint('Erreur chargement public_matiere_ids: $e');
    }
  }

  static Future<void> _savePublicMatiereIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ngenou_public_matiere_ids', _publicMatiereIds.toList());
    } catch (_) {}
  }

  /// Interroge rapidement Supabase pour synchroniser la liste des identifiants publics
  static Future<void> syncPublicCourseIds() async {
    await loadPublicMatiereIds();
    try {
      final response = await _client
          .from('teacher_courses')
          .select('matiere_id')
          .eq('is_published', true)
          .timeout(const Duration(seconds: 4));
      final rows = response as List<dynamic>;
      for (final r in rows) {
        final mid = r['matiere_id']?.toString();
        if (mid != null && mid.isNotEmpty) {
          _publicMatiereIds.add(mid);
        }
      }
      _savePublicMatiereIds();
    } catch (e) {
      debugPrint("Info syncPublicCourseIds (hors-ligne/timeout) : $e");
    }
  }

  /// Récupère la liste des cours publiés pour le catalogue (avec timeout & cache hors-ligne)
  static Future<List<TeacherCourseItem>> fetchCatalog({
    String? schoolLevel,
    String? searchQuery,
  }) async {
    await loadPublicMatiereIds();
    try {
      var query = _client
          .from('teacher_courses')
          .select()
          .eq('is_published', true);

      if (schoolLevel != null && schoolLevel.isNotEmpty && schoolLevel != 'all') {
        if (schoolLevel.toLowerCase() == 'secondaire') {
          query = query.inFilter('school_level', const ['college', 'lycee', 'secondaire']);
        } else {
          query = query.eq('school_level', schoolLevel.toLowerCase());
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('titre', '%${searchQuery.trim()}%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 7));

      final List<TeacherCourseItem> items = [];
      for (final item in response) {
        try {
          items.add(TeacherCourseItem.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (err) {
          debugPrint("Erreur décodage cours catalogue: $err");
        }
      }

      if (items.isNotEmpty) {
        _cachedCatalog = items;
        for (final item in items) {
          _publicMatiereIds.add(item.matiereId);
        }
        _savePublicMatiereIds();
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

      final List<TeacherCourseItem> items = [];
      for (final item in response) {
        try {
          items.add(TeacherCourseItem.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (err) {
          debugPrint("Erreur décodage mes cours: $err");
        }
      }
      return items;
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

    final item = TeacherCourseItem.fromJson(response);
    markAsPublic(item.matiereId);
    return item;
  }

  /// Modifie la visibilité (publié / brouillon) d'un cours
  static Future<void> togglePublishStatus(String courseId, bool currentStatus) async {
    await _client
        .from('teacher_courses')
        .update({'is_published': !currentStatus})
        .eq('id', courseId);
  }

  /// Met à jour un cours existant (json_data + titre + description)
  static Future<void> updateCourse({
    required String courseId,
    required CustomCoursePackage package,
  }) async {
    await _client.from('teacher_courses').update({
      'json_data': package.toJson(),
      'titre': package.matiere.nom.trim(),
      'description': package.matiere.description,
      'matiere_nom': package.matiere.nom,
      'icone': CustomCoursePackage.iconToKey(package.matiere.icone),
      'couleur': CustomCoursePackage.colorToHex(package.matiere.couleur),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', courseId);
  }

  /// Renomme un cours (titre + description) sans toucher au json_data
  static Future<void> renameCourse({
    required String courseId,
    required String titre,
    required String description,
  }) async {
    await _client.from('teacher_courses').update({
      'titre': titre.trim(),
      'description': description,
      'matiere_nom': titre.trim(),
    }).eq('id', courseId);
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
