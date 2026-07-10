import 'schedule_activity_type.dart';
import 'task_priority.dart';

enum TaskStatus { pending, completed, cancelled, snoozed }

class StudyTask {
  static const manualScheduleId = 'system_manual';

  static const lifeRhythmMatiereId = 'life_rhythm';

  final String id;
  final String scheduleId;
  final String matiereId;
  final String matiereNom;
  final String? title;
  final String? projetId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final TaskStatus status;
  final TaskPriority priority;
  final ScheduleActivityType activityType;
  final int? notificationId;

  const StudyTask({
    required this.id,
    required this.scheduleId,
    required this.matiereId,
    required this.matiereNom,
    this.title,
    this.projetId,
    required this.scheduledAt,
    required this.durationMinutes,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.activityType = ScheduleActivityType.study,
    this.notificationId,
  });

  bool get isPending => status == TaskStatus.pending || status == TaskStatus.snoozed;
  bool get isManual => scheduleId == manualScheduleId;
  bool get isStudyActivity => activityType == ScheduleActivityType.study;
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (activityType != ScheduleActivityType.study) {
      return activityType.label;
    }
    return matiereNom;
  }

  bool get triggersAlarm => activityType.triggersAlarm;

  bool get isLate =>
      isPending && scheduledAt.isBefore(DateTime.now());

  StudyTask copyWith({
    String? matiereId,
    String? matiereNom,
    String? title,
    String? projetId,
    DateTime? scheduledAt,
    int? durationMinutes,
    TaskStatus? status,
    TaskPriority? priority,
    ScheduleActivityType? activityType,
    int? notificationId,
  }) =>
      StudyTask(
        id: id,
        scheduleId: scheduleId,
        matiereId: matiereId ?? this.matiereId,
        matiereNom: matiereNom ?? this.matiereNom,
        title: title ?? this.title,
        projetId: projetId ?? this.projetId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        activityType: activityType ?? this.activityType,
        notificationId: notificationId ?? this.notificationId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'matiere_id': matiereId,
        'matiere_nom': matiereNom,
        'title': title,
        'projet_id': projetId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_minutes': durationMinutes,
        'status': status.name,
        'priority': priority.name,
        'activity_type': activityType.name,
        'notification_id': notificationId,
      };

  factory StudyTask.fromMap(Map<String, dynamic> map) => StudyTask(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        matiereId: map['matiere_id'] as String,
        matiereNom: map['matiere_nom'] as String,
        title: map['title'] as String?,
        projetId: map['projet_id'] as String?,
        scheduledAt: DateTime.parse(map['scheduled_at'] as String),
        durationMinutes: map['duration_minutes'] as int,
        status: TaskStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => TaskStatus.pending,
        ),
        priority: TaskPriority.fromString(map['priority'] as String?),
        activityType: ScheduleActivityType.fromString(map['activity_type'] as String?),
        notificationId: map['notification_id'] as int?,
      );
}
