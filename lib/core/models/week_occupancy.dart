/// Créneaux où l'utilisateur est indisponible (cours, travail, déjeuner…).
class BusyBlock {
  final String startTime;
  final String endTime;
  final String label;

  const BusyBlock({
    required this.startTime,
    required this.endTime,
    this.label = 'Occupé',
  });

  BusyBlock copyWith({String? startTime, String? endTime, String? label}) =>
      BusyBlock(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'label': label,
      };

  factory BusyBlock.fromJson(Map<String, dynamic> json) => BusyBlock(
        startTime: json['startTime'] as String? ?? '08:00',
        endTime: json['endTime'] as String? ?? '12:00',
        label: json['label'] as String? ?? 'Occupé',
      );
}

class DayOccupancy {
  final List<BusyBlock> busyBlocks;

  const DayOccupancy({this.busyBlocks = const []});

  DayOccupancy copyWith({List<BusyBlock>? busyBlocks}) =>
      DayOccupancy(busyBlocks: busyBlocks ?? this.busyBlocks);

  Map<String, dynamic> toJson() => {
        'busyBlocks': busyBlocks.map((b) => b.toJson()).toList(),
      };

  factory DayOccupancy.fromJson(Map<String, dynamic> json) => DayOccupancy(
        busyBlocks: (json['busyBlocks'] as List<dynamic>? ?? [])
            .map((e) => BusyBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Disponibilité inverse : on saisit quand on est occupé, l'IA remplit le reste.
class WeekOccupancy {
  final DayOccupancy weekdays;
  final DayOccupancy saturday;
  final DayOccupancy sunday;
  final int targetSleepHours;

  const WeekOccupancy({
    required this.weekdays,
    required this.saturday,
    required this.sunday,
    this.targetSleepHours = 8,
  });

  static WeekOccupancy defaults() => const WeekOccupancy(
        weekdays: DayOccupancy(
          busyBlocks: [
            BusyBlock(startTime: '08:00', endTime: '12:00', label: 'Cours / Travail'),
            BusyBlock(startTime: '12:00', endTime: '13:30', label: 'Déjeuner'),
            BusyBlock(startTime: '13:30', endTime: '17:00', label: 'Cours / Travail'),
          ],
        ),
        saturday: DayOccupancy(
          busyBlocks: [
            BusyBlock(startTime: '10:00', endTime: '12:00', label: 'Courses / sorties'),
          ],
        ),
        sunday: DayOccupancy(),
        targetSleepHours: 8,
      );

  DayOccupancy occupancyForWeekday(int weekday) {
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) return weekdays;
    if (weekday == DateTime.saturday) return saturday;
    return sunday;
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'targetSleepHours': targetSleepHours,
        'weekdays': weekdays.toJson(),
        'saturday': saturday.toJson(),
        'sunday': sunday.toJson(),
      };

  factory WeekOccupancy.fromJson(Map<String, dynamic> json) {
    if (json['version'] == 2) {
      return WeekOccupancy(
        weekdays: DayOccupancy.fromJson(json['weekdays'] as Map<String, dynamic>? ?? {}),
        saturday: DayOccupancy.fromJson(json['saturday'] as Map<String, dynamic>? ?? {}),
        sunday: DayOccupancy.fromJson(json['sunday'] as Map<String, dynamic>? ?? {}),
        targetSleepHours: (json['targetSleepHours'] as num?)?.toInt() ?? 8,
      );
    }
    return _migrateLegacyRoutine(json);
  }

  /// Ancien format : créneaux de révision disponibles → heures occupées par défaut.
  static WeekOccupancy _migrateLegacyRoutine(Map<String, dynamic> json) {
    final defaults = WeekOccupancy.defaults();
    if (!json.containsKey('weekdays')) return defaults;

    final legacyWeek = json['weekdays'] as Map<String, dynamic>?;
    if (legacyWeek == null) return defaults;

    final enabled = legacyWeek['enabled'] as bool? ?? false;
    if (!enabled) return defaults;

    return defaults;
  }
}
