import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_release.dart';
import '../models/release_feature.dart';
import 'supabase_config.dart';

/// Repository gérant les versions de l'application et leurs fonctionnalités
class ReleaseRepository {
  final SupabaseClient? _client;

  ReleaseRepository([SupabaseClient? client])
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  /// Récupère toutes les versions publiées avec leurs fonctionnalités (Public)
  Future<List<AppRelease>> getPublishedReleases() async {
    if (_client == null) {
      return _getFallbackReleases();
    }

    try {
      final response = await _client
          .from('app_releases')
          .select('*, release_features(*)')
          .eq('is_published', true)
          .order('published_at', ascending: false);

      return (response as List).map((row) {
        final featuresJson = row['release_features'] as List? ?? [];
        final features = featuresJson
            .map((f) => ReleaseFeature.fromJson(f as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        return AppRelease.fromJson(
          row as Map<String, dynamic>,
          features: features,
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des versions : $e');
      return _getFallbackReleases();
    }
  }

  /// Récupère la dernière version publiée (pour le bouton Télécharger)
  Future<AppRelease?> getLatestPublishedRelease() async {
    if (_client == null) {
      final fallback = _getFallbackReleases();
      return fallback.isNotEmpty ? fallback.first : null;
    }

    try {
      final response = await _client
          .from('app_releases')
          .select('*, release_features(*)')
          .eq('is_published', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final featuresJson = response['release_features'] as List? ?? [];
      final features = featuresJson
          .map((f) => ReleaseFeature.fromJson(f as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return AppRelease.fromJson(
        response as Map<String, dynamic>,
        features: features,
      );
    } catch (e) {
      debugPrint('Erreur getLatestPublishedRelease: $e');
      final fallback = _getFallbackReleases();
      return fallback.isNotEmpty ? fallback.first : null;
    }
  }

  /// Récupère toutes les versions (brouillon et publiées) pour l'espace admin
  Future<List<AppRelease>> getAllReleasesAdmin() async {
    if (_client == null) {
      return _getFallbackReleases();
    }

    final response = await _client
        .from('app_releases')
        .select('*, release_features(*)')
        .order('version_code', ascending: false);

    return (response as List).map((row) {
      final featuresJson = row['release_features'] as List? ?? [];
      final features = featuresJson
          .map((f) => ReleaseFeature.fromJson(f as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return AppRelease.fromJson(
        row as Map<String, dynamic>,
        features: features,
      );
    }).toList();
  }

  /// Récupère une version spécifique par son identifiant
  Future<AppRelease?> getReleaseById(String id) async {
    if (_client == null) return null;

    final response = await _client
        .from('app_releases')
        .select('*, release_features(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    final featuresJson = response['release_features'] as List? ?? [];
    final features = featuresJson
        .map((f) => ReleaseFeature.fromJson(f as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AppRelease.fromJson(
      response as Map<String, dynamic>,
      features: features,
    );
  }

  /// Crée ou met à jour une version
  Future<AppRelease> saveRelease(AppRelease release) async {
    if (_client == null) {
      throw Exception('Supabase n\'est pas configuré.');
    }

    final data = release.toJson(includeId: false);
    if (release.id.isEmpty) {
      // Insertion
      final res = await _client
          .from('app_releases')
          .insert(data)
          .select()
          .single();
      return AppRelease.fromJson(res);
    } else {
      // Mise à jour
      final res = await _client
          .from('app_releases')
          .update(data)
          .eq('id', release.id)
          .select()
          .single();
      return AppRelease.fromJson(res);
    }
  }

  /// Bascule l'état de publication d'une release
  Future<void> togglePublish(String id, bool publish) async {
    if (_client == null) return;
    await _client.from('app_releases').update({
      'is_published': publish,
      'published_at': publish ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  /// Supprime une version (cascade sur les features)
  Future<void> deleteRelease(String id) async {
    if (_client == null) return;
    await _client.from('app_releases').delete().eq('id', id);
  }

  /// Enregistre les fonctionnalités d'une version
  Future<void> saveFeatures(String releaseId, List<ReleaseFeature> features) async {
    if (_client == null) return;

    // Supprimer les anciennes fonctionnalités
    await _client.from('release_features').delete().eq('release_id', releaseId);

    if (features.isEmpty) return;

    final data = features.asMap().entries.map((entry) {
      final index = entry.key;
      final feat = entry.value;
      return {
        'release_id': releaseId,
        'title': feat.title,
        'body': feat.body,
        'image_url': feat.imageUrl,
        'sort_order': index,
      };
    }).toList();

    await _client.from('release_features').insert(data);
  }

  /// Upload d'une image dans le bucket public "release-media"
  Future<String> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_client == null) {
      throw Exception('Supabase n\'est pas configuré pour le téléversement.');
    }

    final path = 'features/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('release-media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _client.storage.from('release-media').getPublicUrl(path);
    return publicUrl;
  }

  /// Upload d'un APK dans le bucket public "apks"
  Future<String> uploadApk({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_client == null) {
      throw Exception('Supabase n\'est pas configuré pour le téléversement.');
    }

    final path = 'builds/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('apks').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _client.storage.from('apks').getPublicUrl(path);
    return publicUrl;
  }

  /// Données statiques de démonstration en local ou hors-ligne
  List<AppRelease> _getFallbackReleases() {
    return [
      AppRelease(
        id: 'fallback-1',
        versionName: '1.1.0',
        versionCode: 11,
        title: 'Lancement officiel de Ngenou avec Ngenou Assets & Mode Hors-Ligne',
        notes:
            'Cette version apporte le catalogue d\'extensions Ngenou Assets, les défis d\'apprentissage avec série de jours et le tuteur IA avec entrée vocale.',
        apkUrl: 'Ngenou.apk',
        forceUpdate: false,
        isPublished: true,
        publishedAt: DateTime(2026, 10, 28),
        features: [
          const ReleaseFeature(
            id: 'feat-1',
            releaseId: 'fallback-1',
            title: 'Tuteur IA conversationnel socratique',
            body:
                'Posez vos questions par écrit ou par dictée vocale. Le tuteur décompose les étapes et vous aide à comprendre par vous-même sans faire les devoirs à votre place.',
            imageUrl: 'assets/screenshots/tuteur_chat.png',
            sortOrder: 0,
          ),
          const ReleaseFeature(
            id: 'feat-2',
            releaseId: 'fallback-1',
            title: 'Catalogue d\'extensions Ngenou Assets',
            body:
                'Installez uniquement les modules complémentaires utiles à vos matières (sciences, mathématiques, outils de programmation) pour préserver la mémoire de votre téléphone.',
            imageUrl: 'assets/screenshots/extensions_assets.png',
            sortOrder: 1,
          ),
          const ReleaseFeature(
            id: 'feat-3',
            releaseId: 'fallback-1',
            title: 'Emploi du temps & tâches avec alarmes',
            body:
                'Planifiez vos sessions d\'étude semaine par semaine avec rappels et export PDF en un clic. 100% utilisable hors-ligne.',
            imageUrl: 'assets/screenshots/planning_emploi_du_temps.png',
            sortOrder: 2,
          ),
          const ReleaseFeature(
            id: 'feat-4',
            releaseId: 'fallback-1',
            title: 'Défis quotidiens et quiz interactifs',
            body:
                'Chaque jour, testez vos connaissances, gagnez des points d\'expérience et entretenez votre série de jours consécutifs.',
            imageUrl: 'assets/screenshots/defis_quiz.png',
            sortOrder: 3,
          ),
        ],
      ),
    ];
  }
}
