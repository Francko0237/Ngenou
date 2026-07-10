enum TaskPriority {
  normal,
  urgent;

  String get label => switch (this) {
        TaskPriority.normal => 'Normale',
        TaskPriority.urgent => 'Urgente',
      };

  static TaskPriority fromString(String? value) =>
      TaskPriority.values.firstWhere(
        (p) => p.name == value,
        orElse: () => TaskPriority.normal,
      );
}

enum TaskHistoryFilter {
  all,
  completed,
  cancelled;

  String get label => switch (this) {
        TaskHistoryFilter.all => 'Toutes',
        TaskHistoryFilter.completed => 'Effectuées',
        TaskHistoryFilter.cancelled => 'Annulées',
      };
}
