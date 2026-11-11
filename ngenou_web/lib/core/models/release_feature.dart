/// Modèle représentant une fonctionnalité d'une version de Ngenou
class ReleaseFeature {
  final String id;
  final String releaseId;
  final String title;
  final String body;
  final String? imageUrl;
  final int sortOrder;
  final DateTime? createdAt;

  const ReleaseFeature({
    required this.id,
    required this.releaseId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory ReleaseFeature.fromJson(Map<String, dynamic> json) {
    return ReleaseFeature(
      id: json['id'] as String? ?? '',
      releaseId: json['release_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'release_id': releaseId,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'sort_order': sortOrder,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  ReleaseFeature copyWith({
    String? id,
    String? releaseId,
    String? title,
    String? body,
    String? imageUrl,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ReleaseFeature(
      id: id ?? this.id,
      releaseId: releaseId ?? this.releaseId,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
