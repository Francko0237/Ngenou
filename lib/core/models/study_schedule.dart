import 'dart:convert';
import 'schedule_subject.dart';
import 'week_occupancy.dart';

class StudySchedule {
  final String id;
  final String titre;
  final List<ScheduleSubject> subjects;
  final WeekOccupancy occupancy;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool isActive;
  final DateTime dateCreation;

  const StudySchedule({
    required this.id,
    required this.titre,
    required this.subjects,
    required this.occupancy,
    required this.periodStart,
    required this.periodEnd,
    this.isActive = true,
    required this.dateCreation,
  });

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int dayCount(DateTime start, DateTime end) =>
      dateOnly(end).difference(dateOnly(start)).inDays + 1;

  static String formatDate(DateTime d) {
    const months = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String dateRangeLabel(DateTime start, DateTime end) {
    final days = dayCount(start, end);
    return '${formatDate(start)} → ${formatDate(end)} ($days jours)';
  }

  StudySchedule copyWith({
    String? titre,
    List<ScheduleSubject>? subjects,
    WeekOccupancy? occupancy,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool? isActive,
  }) =>
      StudySchedule(
        id: id,
        titre: titre ?? this.titre,
        subjects: subjects ?? this.subjects,
        occupancy: occupancy ?? this.occupancy,
        periodStart: periodStart ?? this.periodStart,
        periodEnd: periodEnd ?? this.periodEnd,
        isActive: isActive ?? this.isActive,
        dateCreation: dateCreation,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'titre': titre,
        'subjects_json': jsonEncode(subjects.map((s) => s.toJson()).toList()),
        'routine_json': jsonEncode(occupancy.toJson()),
        'period_start': dateOnly(periodStart).toIso8601String(),
        'period_end': dateOnly(periodEnd).toIso8601String(),
        'period_weeks': (dayCount(periodStart, periodEnd) / 7).ceil(),
        'is_active': isActive ? 1 : 0,
        'date_creation': dateCreation.toIso8601String(),
      };

  factory StudySchedule.fromMap(Map<String, dynamic> map) {
    final subjectsRaw = jsonDecode(map['subjects_json'] as String) as List<dynamic>;
    final routineRaw = jsonDecode(map['routine_json'] as String) as Map<String, dynamic>;
    final now = DateTime.now();
    final startRaw = map['period_start'] as String?;
    final endRaw = map['period_end'] as String?;
    final weeks = map['period_weeks'] as int? ?? 2;

    final start = startRaw != null
        ? DateTime.parse(startRaw)
        : dateOnly(now);
    final end = endRaw != null
        ? DateTime.parse(endRaw)
        : dateOnly(now).add(Duration(days: weeks * 7 - 1));

    return StudySchedule(
      id: map['id'] as String,
      titre: map['titre'] as String,
      subjects: subjectsRaw.map((e) => ScheduleSubject.fromJson(e as Map<String, dynamic>)).toList(),
      occupancy: WeekOccupancy.fromJson(routineRaw),
      periodStart: start,
      periodEnd: end,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      dateCreation: DateTime.parse(map['date_creation'] as String),
    );
  }
}
