import 'dart:convert';
import '../models/schedule_activity_type.dart';
import '../models/schedule_subject.dart';
import '../models/study_task.dart';
import '../models/study_schedule.dart';
import '../models/week_occupancy.dart';

class SchedulePromptBuilder {
  static const _dayAtmosphere = '''
- Lundi : reprise — énergie progressive, révision modérée en fin de journée, sommeil régulier.
- Mardi : pic de concentration — bonnes sessions d'étude en fin d'après-midi / début de soirée.
- Mercredi : milieu de semaine — alterner matières difficiles et plus légères, pause sociale utile.
- Jeudi : productivité élevée — sessions un peu plus longues si la matière l'exige.
- Vendredi : fatigue accumulée — sessions courtes (25–40 min), plus de détente le soir.
- Samedi : week-end — motivation faible même si libre, MAX 1 session courte (30–45 min), privilégier détente et sorties.
- Dimanche : repos — sommeil récupérateur, révision TRÈS légère en fin d'après-midi si nécessaire, sinon détente.''';

  static String build({
    required String titre,
    required List<ScheduleSubject> subjects,
    required WeekOccupancy occupancy,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final subjectsBlock = subjects
        .map((s) => '- ${s.nom} (id: ${s.matiereId}, durée totale à couvrir: ${s.durationMinutes} min)')
        .join('\n');

    final busyBlock = _occupancyText(occupancy);
    final rangeLabel = StudySchedule.dateRangeLabel(periodStart, periodEnd);
    final days = StudySchedule.dayCount(periodStart, periodEnd);

    return '''# RÔLE
Tu es un coach en gestion du temps, neurosciences de l'apprentissage et bien-être. Génère UNIQUEMENT un JSON brut.

# OBJECTIF
Construire un emploi du temps COMPLET et réaliste sur la période. L'utilisateur indique quand il est OCCUPÉ (indisponible). Tu remplis intelligemment le reste de la journée type avec :
- sommeil (${occupancy.targetSleepHours}h cible, horaires adaptés par jour pour la mémorisation)
- révisions par matière (respecter les durées totales, sessions 25–50 min)
- pauses courtes entre sessions d'étude (5–15 min)
- distractions / plaisir planifiées (réseaux, jeux, séries, amis…)
- repas si non déjà couverts par les créneaux occupés

# EMPLOI DU TEMPS
Titre : $titre
Période : $rangeLabel ($days jours calendaires — le modèle hebdo sera répété sur chaque semaine)

# MATIÈRES À RÉVISER
$subjectsBlock

# CRÉNEAUX OCCUPÉS (INDISPONIBILITÉ — ne jamais chevaucher)
$busyBlock

# ATMOSPHÈRE & ÉNERGIE PAR JOUR
$_dayAtmosphere

# RÈGLES IMPORTANTES
1. Les créneaux "occupied" ci-dessus sont FIXES chaque semaine — reproduis-les dans le modèle.
2. Ne programme PAS d'étude pendant le sommeil ni pendant les créneaux occupés.
3. Week-end : même si peu occupé, NE SURCHARGE PAS — les gens n'aiment pas étudier le samedi/dimanche.
4. Varie les horaires d'étude selon le jour (pas toujours la même heure).
5. Place le sommeil en bloc continu (typiquement 22h30–07h00 mais adapte par jour).
6. Inclus au moins 1 bloc "distraction" par jour en semaine, plus le week-end.
7. dayOfWeek : 1=lundi … 7=dimanche.
8. activityType : "study" | "sleep" | "breakTime" | "distraction" | "meal" | "occupied" | "other"
9. Pour "study" : matiereId et matiereNom obligatoires. Pour les autres : label descriptif.

# SCHÉMA JSON OBLIGATOIRE
{
  "weeklyPattern": [
    {
      "dayOfWeek": 1,
      "blocks": [
        {
          "activityType": "occupied",
          "startTime": "08:00",
          "durationMinutes": 240,
          "label": "Cours"
        },
        {
          "activityType": "sleep",
          "startTime": "23:00",
          "durationMinutes": 480,
          "label": "Sommeil"
        },
        {
          "activityType": "study",
          "matiereId": "id_exact",
          "matiereNom": "Nom",
          "startTime": "19:00",
          "durationMinutes": 40,
          "label": "Révision Maths"
        },
        {
          "activityType": "distraction",
          "startTime": "21:00",
          "durationMinutes": 45,
          "label": "Détente"
        }
      ]
    }
  ]
}

Génère un modèle pour CHAQUE jour (1 à 7) avec tous les blocs de la journée, du réveil au coucher. JSON uniquement.''';
  }

  static String _occupancyText(WeekOccupancy o) {
    String dayBlock(String title, DayOccupancy day) {
      if (day.busyBlocks.isEmpty) return '$title : aucun créneau occupé (journée libre)';
      final lines = day.busyBlocks
          .map((b) => '  • ${b.startTime}–${b.endTime} : ${b.label}')
          .join('\n');
      return '$title :\n$lines';
    }

    return '''${dayBlock('Lundi → Vendredi', o.weekdays)}
${dayBlock('Samedi', o.saturday)}
${dayBlock('Dimanche', o.sunday)}
Sommeil cible : ${o.targetSleepHours} h / nuit''';
  }

  static List<StudyTask> parseAndMaterialize({
    required String scheduleId,
    required String rawJson,
    required List<ScheduleSubject> subjects,
    required WeekOccupancy occupancy,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    try {
      final decoded = jsonDecode(_cleanJson(rawJson)) as Map<String, dynamic>;
      final pattern = decoded['weeklyPattern'] as List<dynamic>?;
      if (pattern != null && pattern.isNotEmpty) {
        final tasks = _materializeWeeklyPattern(
          scheduleId,
          pattern,
          subjects,
          occupancy,
          periodStart,
          periodEnd,
        );
        if (tasks.isNotEmpty) return tasks;
      }
      final legacyTasks = decoded['tasks'] as List<dynamic>?;
      if (legacyTasks != null && legacyTasks.isNotEmpty) {
        return _materializeLegacyStudyOnly(
          scheduleId,
          legacyTasks,
          subjects,
          periodStart,
          periodEnd,
        );
      }
    } catch (_) {}

    return _materializeFallback(
      scheduleId,
      subjects,
      occupancy,
      periodStart,
      periodEnd,
    );
  }

  static List<StudyTask> _materializeWeeklyPattern(
    String scheduleId,
    List<dynamic> pattern,
    List<ScheduleSubject> subjects,
    WeekOccupancy occupancy,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final subjectMap = {for (final s in subjects) s.matiereId: s};
    final dayPatterns = <int, List<_BlockPattern>>{};

    for (final raw in pattern) {
      if (raw is! Map<String, dynamic>) continue;
      final dow = (raw['dayOfWeek'] as num?)?.toInt();
      if (dow == null || dow < 1 || dow > 7) continue;
      final blocks = raw['blocks'] as List<dynamic>? ?? [];
      final parsed = <_BlockPattern>[];
      for (final b in blocks) {
        if (b is! Map<String, dynamic>) continue;
        final p = _BlockPattern.fromJson(b, subjectMap);
        if (p != null) parsed.add(p);
      }
      if (parsed.isNotEmpty) dayPatterns[dow] = parsed;
    }

    _injectFixedOccupiedBlocks(dayPatterns, occupancy);

    if (dayPatterns.isEmpty) return [];

    final tasks = <StudyTask>[];
    final now = DateTime.now();
    var day = StudySchedule.dateOnly(periodStart);
    final end = StudySchedule.dateOnly(periodEnd);

    while (!day.isAfter(end)) {
      final blocks = dayPatterns[day.weekday] ?? [];
      for (final p in blocks) {
        final scheduled = _parseTime(day, p.startTime);
        if (scheduled.isBefore(now)) continue;
        tasks.add(_toStudyTask(scheduleId, scheduled, p));
      }
      day = day.add(const Duration(days: 1));
    }

    tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return tasks;
  }

  static void _injectFixedOccupiedBlocks(
    Map<int, List<_BlockPattern>> dayPatterns,
    WeekOccupancy occupancy,
  ) {
    for (var dow = 1; dow <= 7; dow++) {
      final busy = occupancy.occupancyForWeekday(dow).busyBlocks;
      if (busy.isEmpty) continue;
      final list = dayPatterns.putIfAbsent(dow, () => []);
      for (final b in busy) {
        final mins = _minutesBetween(b.startTime, b.endTime);
        if (mins <= 0) continue;
        final exists = list.any((p) =>
            p.activityType == ScheduleActivityType.occupied &&
            p.startTime == b.startTime &&
            p.durationMinutes == mins);
        if (!exists) {
          list.add(_BlockPattern(
            activityType: ScheduleActivityType.occupied,
            startTime: b.startTime,
            durationMinutes: mins,
            label: b.label,
          ));
        }
      }
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  static List<StudyTask> _materializeLegacyStudyOnly(
    String scheduleId,
    List<dynamic> tasksRaw,
    List<ScheduleSubject> subjects,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final subjectMap = {for (final s in subjects) s.matiereId: s};
    final patterns = <_BlockPattern>[];

    for (final raw in tasksRaw) {
      if (raw is! Map<String, dynamic>) continue;
      final matiereId = raw['matiereId'] as String?;
      if (matiereId == null || !subjectMap.containsKey(matiereId)) continue;
      final sub = subjectMap[matiereId]!;
      patterns.add(_BlockPattern(
        activityType: ScheduleActivityType.study,
        matiereId: matiereId,
        matiereNom: raw['matiereNom'] as String? ?? sub.nom,
        projetId: sub.projetId,
        dayOfWeek: (raw['dayOfWeek'] as num?)?.toInt() ?? 1,
        startTime: raw['startTime'] as String? ?? '18:00',
        durationMinutes: (raw['durationMinutes'] as num?)?.toInt() ?? 45,
        label: raw['matiereNom'] as String? ?? sub.nom,
      ));
    }

    if (patterns.isEmpty) return [];

    final tasks = <StudyTask>[];
    final now = DateTime.now();
    var day = StudySchedule.dateOnly(periodStart);
    final end = StudySchedule.dateOnly(periodEnd);

    while (!day.isAfter(end)) {
      for (final p in patterns) {
        if (p.dayOfWeek != null && day.weekday != p.dayOfWeek) continue;
        final scheduled = _parseTime(day, p.startTime);
        if (scheduled.isBefore(now)) continue;
        tasks.add(_toStudyTask(scheduleId, scheduled, p));
      }
      day = day.add(const Duration(days: 1));
    }
    return tasks;
  }

  static List<StudyTask> _materializeFallback(
    String scheduleId,
    List<ScheduleSubject> subjects,
    WeekOccupancy occupancy,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final tasks = <StudyTask>[];
    final now = DateTime.now();
    var subjectIndex = 0;
    var day = StudySchedule.dateOnly(periodStart);
    final end = StudySchedule.dateOnly(periodEnd);

    while (!day.isAfter(end)) {
      final dow = day.weekday;
      final isWeekend = dow == DateTime.saturday || dow == DateTime.sunday;

      for (final b in occupancy.occupancyForWeekday(dow).busyBlocks) {
        final start = _parseTime(day, b.startTime);
        if (!start.isBefore(now)) {
          tasks.add(_toStudyTask(
            scheduleId,
            start,
            _BlockPattern(
              activityType: ScheduleActivityType.occupied,
              startTime: b.startTime,
              durationMinutes: _minutesBetween(b.startTime, b.endTime),
              label: b.label,
            ),
          ));
        }
      }

      final sleepStart = isWeekend ? '00:00' : '23:00';
      final sleepStartDt = _parseTime(day, sleepStart);
      if (!sleepStartDt.isBefore(now)) {
        tasks.add(_toStudyTask(
          scheduleId,
          sleepStartDt,
          _BlockPattern(
            activityType: ScheduleActivityType.sleep,
            startTime: sleepStart,
            durationMinutes: occupancy.targetSleepHours * 60,
            label: 'Sommeil',
          ),
        ));
      }

      if (!isWeekend && subjects.isNotEmpty) {
        final studyHour = switch (dow) {
          DateTime.monday => '18:30',
          DateTime.friday => '17:30',
          _ => '19:00',
        };
        final start = _parseTime(day, studyHour);
        if (!start.isBefore(now) && !_overlapsBusy(start, 40, occupancy.occupancyForWeekday(dow))) {
          final sub = subjects[subjectIndex % subjects.length];
          subjectIndex++;
          tasks.add(_toStudyTask(
            scheduleId,
            start,
            _BlockPattern(
              activityType: ScheduleActivityType.study,
              matiereId: sub.matiereId,
              matiereNom: sub.nom,
              projetId: sub.projetId,
              startTime: studyHour,
              durationMinutes: 40,
              label: sub.nom,
            ),
          ));
          final breakStart = start.add(const Duration(minutes: 45));
          if (!breakStart.isBefore(now)) {
            tasks.add(_toStudyTask(
              scheduleId,
              breakStart,
              _BlockPattern(
                activityType: ScheduleActivityType.breakTime,
                startTime: _formatTime(breakStart),
                durationMinutes: 10,
                label: 'Pause',
              ),
            ));
          }
        }
      } else if (dow == DateTime.saturday && subjects.isNotEmpty) {
        final start = _parseTime(day, '11:00');
        if (!start.isBefore(now)) {
          final sub = subjects[subjectIndex % subjects.length];
          subjectIndex++;
          tasks.add(_toStudyTask(
            scheduleId,
            start,
            _BlockPattern(
              activityType: ScheduleActivityType.study,
              matiereId: sub.matiereId,
              matiereNom: sub.nom,
              projetId: sub.projetId,
              startTime: '11:00',
              durationMinutes: 30,
              label: sub.nom,
            ),
          ));
        }
        final dist = _parseTime(day, '15:00');
        if (!dist.isBefore(now)) {
          tasks.add(_toStudyTask(
            scheduleId,
            dist,
            _BlockPattern(
              activityType: ScheduleActivityType.distraction,
              startTime: '15:00',
              durationMinutes: 90,
              label: 'Détente',
            ),
          ));
        }
      }

      day = day.add(const Duration(days: 1));
    }

    tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return tasks;
  }

  static bool _overlapsBusy(DateTime start, int durationMin, DayOccupancy day) {
    final end = start.add(Duration(minutes: durationMin));
    for (final b in day.busyBlocks) {
      final bStart = _parseTime(start, b.startTime);
      final bEnd = _parseTime(start, b.endTime);
      if (start.isBefore(bEnd) && end.isAfter(bStart)) return true;
    }
    return false;
  }

  static StudyTask _toStudyTask(String scheduleId, DateTime scheduled, _BlockPattern p) {
    final isStudy = p.activityType == ScheduleActivityType.study;
    return StudyTask(
      id: 'task_${scheduleId}_${scheduled.millisecondsSinceEpoch}_${p.activityType.name}',
      scheduleId: scheduleId,
      matiereId: isStudy ? (p.matiereId ?? 'manual') : StudyTask.lifeRhythmMatiereId,
      matiereNom: isStudy ? (p.matiereNom ?? p.label) : p.label,
      title: p.label,
      projetId: p.projetId,
      scheduledAt: scheduled,
      durationMinutes: p.durationMinutes,
      activityType: p.activityType,
    );
  }

  static DateTime _parseTime(DateTime day, String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static int _minutesBetween(String start, String end) {
    final s = start.split(':');
    final e = end.split(':');
    final sm = (int.tryParse(s[0]) ?? 0) * 60 + (int.tryParse(s[1]) ?? 0);
    final em = (int.tryParse(e[0]) ?? 0) * 60 + (int.tryParse(e[1]) ?? 0);
    var diff = em - sm;
    if (diff <= 0) diff += 24 * 60;
    return diff;
  }

  static String _cleanJson(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      final end = s.indexOf('\n');
      if (end != -1) s = s.substring(end + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}

class _BlockPattern {
  final ScheduleActivityType activityType;
  final String? matiereId;
  final String? matiereNom;
  final String? projetId;
  final int? dayOfWeek;
  final String startTime;
  final int durationMinutes;
  final String label;

  _BlockPattern({
    required this.activityType,
    this.matiereId,
    this.matiereNom,
    this.projetId,
    this.dayOfWeek,
    required this.startTime,
    required this.durationMinutes,
    required this.label,
  });

  static _BlockPattern? fromJson(
    Map<String, dynamic> json,
    Map<String, ScheduleSubject> subjectMap,
  ) {
    final type = ScheduleActivityType.fromString(json['activityType'] as String?);
    final start = json['startTime'] as String? ?? '08:00';
    final duration = (json['durationMinutes'] as num?)?.toInt() ?? 30;
    final label = json['label'] as String? ?? type.label;

    if (type == ScheduleActivityType.study) {
      final matiereId = json['matiereId'] as String?;
      if (matiereId == null || !subjectMap.containsKey(matiereId)) return null;
      final sub = subjectMap[matiereId]!;
      return _BlockPattern(
        activityType: type,
        matiereId: matiereId,
        matiereNom: json['matiereNom'] as String? ?? sub.nom,
        projetId: sub.projetId,
        startTime: start,
        durationMinutes: duration,
        label: label,
      );
    }

    return _BlockPattern(
      activityType: type,
      startTime: start,
      durationMinutes: duration,
      label: label,
    );
  }
}
