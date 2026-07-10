enum ScheduleActivityType {
  study,
  sleep,
  breakTime,
  distraction,
  meal,
  occupied,
  other;

  String get label => switch (this) {
        ScheduleActivityType.study => 'Révision',
        ScheduleActivityType.sleep => 'Sommeil',
        ScheduleActivityType.breakTime => 'Pause',
        ScheduleActivityType.distraction => 'Détente',
        ScheduleActivityType.meal => 'Repas',
        ScheduleActivityType.occupied => 'Occupé',
        ScheduleActivityType.other => 'Autre',
      };

  bool get triggersAlarm => this == ScheduleActivityType.study;

  bool get canComplete => this == ScheduleActivityType.study;

  static ScheduleActivityType fromString(String? value) =>
      ScheduleActivityType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ScheduleActivityType.study,
      );
}
