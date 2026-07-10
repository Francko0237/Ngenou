class DaySlot {
  final bool enabled;
  final String startTime; // "HH:mm"
  final String endTime;

  const DaySlot({
    required this.enabled,
    required this.startTime,
    required this.endTime,
  });

  DaySlot copyWith({bool? enabled, String? startTime, String? endTime}) =>
      DaySlot(
        enabled: enabled ?? this.enabled,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory DaySlot.fromJson(Map<String, dynamic> json) => DaySlot(
        enabled: json['enabled'] as bool? ?? false,
        startTime: json['startTime'] as String? ?? '18:00',
        endTime: json['endTime'] as String? ?? '21:00',
      );

  static const defaultWeekdays = DaySlot(enabled: true, startTime: '18:00', endTime: '21:00');
  static const defaultSaturday = DaySlot(enabled: true, startTime: '10:00', endTime: '12:00');
  static const defaultSunday = DaySlot(enabled: false, startTime: '10:00', endTime: '12:00');
}

/// Routine hebdomadaire : lun-ven partagent un créneau, sam et dim séparés.
class WeekRoutine {
  final DaySlot weekdays; // lundi → vendredi
  final DaySlot saturday;
  final DaySlot sunday;

  const WeekRoutine({
    required this.weekdays,
    required this.saturday,
    required this.sunday,
  });

  static WeekRoutine defaults() => const WeekRoutine(
        weekdays: DaySlot.defaultWeekdays,
        saturday: DaySlot.defaultSaturday,
        sunday: DaySlot.defaultSunday,
      );

  DaySlot slotForWeekday(int weekday) {
    // DateTime.weekday: 1=lun … 7=dim
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) return weekdays;
    if (weekday == DateTime.saturday) return saturday;
    return sunday;
  }

  Map<String, dynamic> toJson() => {
        'weekdays': weekdays.toJson(),
        'saturday': saturday.toJson(),
        'sunday': sunday.toJson(),
      };

  factory WeekRoutine.fromJson(Map<String, dynamic> json) => WeekRoutine(
        weekdays: DaySlot.fromJson(json['weekdays'] as Map<String, dynamic>? ?? {}),
        saturday: DaySlot.fromJson(json['saturday'] as Map<String, dynamic>? ?? {}),
        sunday: DaySlot.fromJson(json['sunday'] as Map<String, dynamic>? ?? {}),
      );
}
