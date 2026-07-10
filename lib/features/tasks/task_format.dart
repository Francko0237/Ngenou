import 'package:flutter/material.dart';
import '../../core/models/schedule_activity_type.dart';

class TaskFormat {
  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _monthsShort = [
    'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
  ];

  static String longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  static String shortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

  static String time(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String timeRange(DateTime start, int durationMinutes) {
    final end = start.add(Duration(minutes: durationMinutes));
    return '${time(start)} - ${time(end)}';
  }

  static String weekdayShort(DateTime d) {
    const days = ['LUN.', 'MAR.', 'MER.', 'JEU.', 'VEN.', 'SAM.', 'DIM.'];
    return '${days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

Color taskAccentColor(String key, BuildContext context) {
  final palette = [
    const Color(0xFF5C6BC0),
    const Color(0xFF26A69A),
    const Color(0xFFEF6C00),
    const Color(0xFF8E24AA),
    const Color(0xFF3949AB),
    const Color(0xFF00897B),
  ];
  return palette[key.hashCode.abs() % palette.length];
}

IconData taskIconFor(String matiereId) {
  if (matiereId == 'manual') return Icons.task_alt_rounded;
  if (matiereId == 'algo') return Icons.menu_book_rounded;
  return Icons.school_rounded;
}

Color activityColor(ScheduleActivityType type, {String? matiereId, BuildContext? context}) {
  return switch (type) {
    ScheduleActivityType.study =>
      matiereId != null && context != null ? taskAccentColor(matiereId, context) : const Color(0xFF5C6BC0),
    ScheduleActivityType.sleep => const Color(0xFF3949AB),
    ScheduleActivityType.breakTime => const Color(0xFF43A047),
    ScheduleActivityType.distraction => const Color(0xFFFB8C00),
    ScheduleActivityType.meal => const Color(0xFF8D6E63),
    ScheduleActivityType.occupied => const Color(0xFF78909C),
    ScheduleActivityType.other => const Color(0xFF757575),
  };
}

IconData activityIcon(ScheduleActivityType type, String matiereId) {
  return switch (type) {
    ScheduleActivityType.study => taskIconFor(matiereId),
    ScheduleActivityType.sleep => Icons.bedtime_rounded,
    ScheduleActivityType.breakTime => Icons.free_breakfast_rounded,
    ScheduleActivityType.distraction => Icons.sports_esports_rounded,
    ScheduleActivityType.meal => Icons.restaurant_rounded,
    ScheduleActivityType.occupied => Icons.work_outline_rounded,
    ScheduleActivityType.other => Icons.schedule_rounded,
  };
}

String activitySubtitle(ScheduleActivityType type) => type.label;
