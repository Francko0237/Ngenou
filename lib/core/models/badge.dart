class AppBadge {
  final String id;
  final String nom;
  final String description;
  final String icone;
  final String category; // 'streak', 'learning', 'algo', 'excellence', 'creative', 'activity'
  final String conditionDesc;
  final DateTime? unlockedAt;

  AppBadge({
    required this.id,
    required this.nom,
    required this.description,
    required this.icone,
    required this.category,
    required this.conditionDesc,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'icone': icone,
      'category': category,
      'condition_desc': conditionDesc,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  factory AppBadge.fromMap(Map<String, dynamic> map) {
    return AppBadge(
      id: map['id'] as String,
      nom: map['nom'] as String,
      description: map['description'] as String,
      icone: map['icone'] as String,
      category: map['category'] as String? ?? 'general',
      conditionDesc: map['condition_desc'] as String? ?? '',
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.tryParse(map['unlocked_at'] as String)
          : null,
    );
  }

  AppBadge copyWith({
    DateTime? unlockedAt,
  }) {
    return AppBadge(
      id: id,
      nom: nom,
      description: description,
      icone: icone,
      category: category,
      conditionDesc: conditionDesc,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
