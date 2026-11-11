import 'release_feature.dart';

/// Modèle représentant une version (release) de l'application Ngenou
class AppRelease {
  final String id;
  final String versionName;
  final int versionCode;
  final String title;
  final String notes;
  final String? apkUrl;
  final bool forceUpdate;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final List<ReleaseFeature> features;

  const AppRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.title,
    required this.notes,
    this.apkUrl,
    this.forceUpdate = false,
    this.isPublished = false,
    this.publishedAt,
    this.createdAt,
    this.features = const [],
  });

  factory AppRelease.fromJson(
    Map<String, dynamic> json, {
    List<ReleaseFeature> features = const [],
  }) {
    return AppRelease(
      id: json['id'] as String? ?? '',
      versionName: json['version_name'] as String? ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      apkUrl: json['apk_url'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      features: features,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'version_name': versionName,
      'version_code': versionCode,
      'title': title,
      'notes': notes,
      'apk_url': apkUrl,
      'force_update': forceUpdate,
      'is_published': isPublished,
      'published_at': publishedAt?.toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  AppRelease copyWith({
    String? id,
    String? versionName,
    int? versionCode,
    String? title,
    String? notes,
    String? apkUrl,
    bool? forceUpdate,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? createdAt,
    List<ReleaseFeature>? features,
  }) {
    return AppRelease(
      id: id ?? this.id,
      versionName: versionName ?? this.versionName,
      versionCode: versionCode ?? this.versionCode,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      apkUrl: apkUrl ?? this.apkUrl,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      features: features ?? this.features,
    );
  }
}
