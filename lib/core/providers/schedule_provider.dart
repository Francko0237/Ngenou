import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/schedule_subject.dart';
import '../models/study_schedule.dart';
import '../models/study_task.dart';
import '../models/task_priority.dart';
import '../models/week_occupancy.dart';
import '../services/deep_seek_service.dart';
import '../services/home_widget_service.dart';
import '../services/schedule_notification_service.dart';
import '../services/schedule_prompt_builder.dart';

class ScheduleProvider with ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<StudySchedule> _schedules = [];
  List<StudyTask> _upcomingTasks = [];
  int _todayStudyTaskCount = 0;
  bool _loading = false;
  DateTime? _lastTaskMutationAt;
  String? _lastAiError;

  List<StudySchedule> get schedules => _schedules;
  List<StudyTask> get upcomingTasks => _upcomingTasks;
  int get todayStudyTaskCount => _todayStudyTaskCount;
  bool get isLoading => _loading;
  DateTime? get lastTaskMutationAt => _lastTaskMutationAt;
  String? get lastAiError => _lastAiError;

  void _markTaskMutated(DateTime at) => _lastTaskMutationAt = at;

  Future<void> _syncTodayStudyTaskCount() async {
    final tasks = await _db.getTasksForDate(DateTime.now());
    _todayStudyTaskCount = tasks
        .where((t) => t.isStudyActivity || t.isManual)
        .length;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    await _db.ensureManualScheduleExists();
    _schedules = await _db.getAllSchedules();
    _upcomingTasks = await _db.getUpcomingTasks();
    await _syncTodayStudyTaskCount();
    _loading = false;
    // Met à jour les widgets du bureau après chaque chargement complet
    final todayTasks = await _db.getTasksForDate(DateTime.now());
    HomeWidgetService.instance.updateTasksWidget(todayTasks); // fire-and-forget
    notifyListeners();
  }

  /// Rafraîchissement léger : met à jour uniquement _upcomingTasks sans reschedule complet.
  /// Utilisé après les mutations simples (ajout/modif/suppression d'une tâche unique)
  /// pour éviter le coût de ScheduleNotificationService.rescheduleAll.
  Future<void> _lightRefresh() async {
    _upcomingTasks = await _db.getUpcomingTasks();
    await _syncTodayStudyTaskCount();
    // Met à jour les widgets du bureau en arrière-plan
    final todayTasks = await _db.getTasksForDate(DateTime.now());
    HomeWidgetService.instance.updateTasksWidget(todayTasks); // fire-and-forget
    notifyListeners();
  }

  Future<void> rescheduleAllTasks() async {
    await ScheduleNotificationService.rescheduleAll(
      await _db.getAllPendingTasks(),
    );
  }

  Future<List<StudyTask>> getTasksForSchedule(String scheduleId) =>
      _db.getTasksBySchedule(scheduleId);

  Future<List<StudyTask>> getTasksForDate(DateTime day) =>
      _db.getTasksForDate(day);

  Future<List<StudyTask>> getTaskHistory({
    TaskHistoryFilter filter = TaskHistoryFilter.all,
    String? search,
    DateTime? beforeDate,
  }) => _db.getTaskHistory(
    filter: filter,
    search: search,
    beforeDate: beforeDate,
  );

  int countPendingForDate(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    return _upcomingTasks.where((t) {
      if (!t.isStudyActivity && !t.isManual) return false;
      if (!t.isPending) return false;
      final scheduled = DateTime(
        t.scheduledAt.year,
        t.scheduledAt.month,
        t.scheduledAt.day,
      );
      return scheduled == dayStart;
    }).length;
  }

  Future<StudyTask> addManualTask({
    required String title,
    required DateTime scheduledAt,
    int durationMinutes = 30,
    TaskPriority priority = TaskPriority.normal,
    String? matiereId,
    String? matiereNom,
  }) async {
    final task = StudyTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      scheduleId: StudyTask.manualScheduleId,
      matiereId: matiereId ?? 'manual',
      matiereNom: matiereNom ?? title,
      title: title,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      priority: priority,
    );
    await _db.insertTask(task);
    // Planifie l'alarme en arrière-plan sans bloquer l'UI
    if (task.scheduledAt.isAfter(DateTime.now())) {
      ScheduleNotificationService.scheduleTask(task); // fire-and-forget
    }
    _markTaskMutated(task.scheduledAt);
    await _lightRefresh(); // léger : pas de rescheduleAll
    return task;
  }

  Future<void> updateTaskDetails({
    required String taskId,
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    TaskPriority? priority,
    String? matiereId,
    String? matiereNom,
  }) async {
    final task = await _db.getTaskById(taskId);
    if (task == null) return;
    ScheduleNotificationService.cancelTask(taskId); // fire-and-forget
    final updated = task.copyWith(
      title: title,
      matiereId: matiereId,
      matiereNom: matiereNom ?? title ?? task.matiereNom,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      priority: priority,
      status: TaskStatus.pending,
    );
    await _db.updateTask(updated);
    if (updated.isPending && updated.scheduledAt.isAfter(DateTime.now())) {
      ScheduleNotificationService.scheduleTask(updated); // fire-and-forget
    }
    _markTaskMutated(updated.scheduledAt);
    await _lightRefresh();
  }

  Future<void> deleteTask(String taskId) async {
    final task = await _db.getTaskById(taskId);
    ScheduleNotificationService.cancelTask(taskId); // fire-and-forget
    await _db.deleteTask(taskId);
    if (task != null) _markTaskMutated(task.scheduledAt);
    await _lightRefresh();
  }

  Future<StudySchedule?> getScheduleById(String id) async {
    try {
      return _schedules.firstWhere((s) => s.id == id);
    } catch (_) {
      final all = await _db.getAllSchedules();
      try {
        return all.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<StudySchedule> createSchedule({
    required String titre,
    required List<ScheduleSubject> subjects,
    required WeekOccupancy occupancy,
    required DateTime periodStart,
    required DateTime periodEnd,
    bool useAi = true,
  }) async {
    final scheduleId = 'schedule_${DateTime.now().millisecondsSinceEpoch}';
    final schedule = StudySchedule(
      id: scheduleId,
      titre: titre,
      subjects: subjects,
      occupancy: occupancy,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dateCreation: DateTime.now(),
    );

    List<StudyTask> tasks;
    if (useAi) {
      tasks = await _generateTasks(
        scheduleId: scheduleId,
        titre: titre,
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    } else {
      tasks = SchedulePromptBuilder.parseAndMaterialize(
        scheduleId: scheduleId,
        rawJson: '{}',
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    }

    await _db.insertSchedule(schedule);
    await _db.insertTasks(tasks);
    await ScheduleNotificationService.rescheduleAll(
      await _db.getAllPendingTasks(),
    );

    await load();
    return schedule;
  }

  Future<StudySchedule> updateSchedule({
    required String scheduleId,
    required String titre,
    required List<ScheduleSubject> subjects,
    required WeekOccupancy occupancy,
    required DateTime periodStart,
    required DateTime periodEnd,
    bool regenerateTasks = true,
  }) async {
    final existing = _schedules.firstWhere((s) => s.id == scheduleId);
    final updated = existing.copyWith(
      titre: titre,
      subjects: subjects,
      occupancy: occupancy,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    await _db.updateSchedule(updated);

    if (regenerateTasks) {
      final oldTasks = await _db.getTasksBySchedule(scheduleId);
      for (final t in oldTasks) {
        await ScheduleNotificationService.cancelTask(t.id);
      }
      await _db.deleteTasksBySchedule(scheduleId);

      final tasks = await _generateTasks(
        scheduleId: scheduleId,
        titre: titre,
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      await _db.insertTasks(tasks);
      await ScheduleNotificationService.rescheduleAll(
        await _db.getAllPendingTasks(),
      );
    }

    await load();
    return updated;
  }

  Future<List<StudyTask>> _generateTasks({
    required String scheduleId,
    required String titre,
    required List<ScheduleSubject> subjects,
    required WeekOccupancy occupancy,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final prompt = SchedulePromptBuilder.build(
        titre: titre,
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      final result = await DeepSeekService.generateProgram(prompt);
      _lastAiError = null;
      return SchedulePromptBuilder.parseAndMaterialize(
        scheduleId: scheduleId,
        rawJson: result.content,
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    } catch (e) {
      _lastAiError = e.toString();
      debugPrint('AI schedule generation failed: $e, using fallback');
      return SchedulePromptBuilder.parseAndMaterialize(
        scheduleId: scheduleId,
        rawJson: '{}',
        subjects: subjects,
        occupancy: occupancy,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    }
  }

  Future<void> regenerateSchedule(String scheduleId) async {
    final schedule = _schedules.firstWhere((s) => s.id == scheduleId);
    await _db.deleteTasksBySchedule(scheduleId);

    final tasks = await _generateTasks(
      scheduleId: scheduleId,
      titre: schedule.titre,
      subjects: schedule.subjects,
      occupancy: schedule.occupancy,
      periodStart: schedule.periodStart,
      periodEnd: schedule.periodEnd,
    );

    await _db.insertTasks(tasks);
    await ScheduleNotificationService.rescheduleAll(
      await _db.getAllPendingTasks(),
    );
    await load();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final tasks = await _db.getTasksBySchedule(scheduleId);
    for (final t in tasks) {
      await ScheduleNotificationService.cancelTask(t.id);
    }
    await _db.deleteSchedule(scheduleId);
    await load();
  }

  Future<void> completeTask(String taskId) async {
    final task = await _db.getTaskById(taskId);
    if (task == null) return;
    await ScheduleNotificationService.dismissTaskNotifications(taskId);
    await ScheduleNotificationService.cancelTask(taskId);
    await _db.updateTask(task.copyWith(status: TaskStatus.completed));
    ScheduleNotificationService.acknowledgeTask(taskId);
    _markTaskMutated(task.scheduledAt);
    await load();
  }

  Future<void> cancelTask(String taskId) async {
    final task = await _db.getTaskById(taskId);
    if (task == null) return;
    await ScheduleNotificationService.dismissTaskNotifications(taskId);
    await ScheduleNotificationService.cancelTask(taskId);
    await _db.updateTask(task.copyWith(status: TaskStatus.cancelled));
    ScheduleNotificationService.acknowledgeTask(taskId);
    await load();
  }

  Future<void> snoozeTask(String taskId, {int minutes = 5}) async {
    final task = await _db.getTaskById(taskId);
    if (task == null) return;
    await ScheduleNotificationService.cancelTask(taskId);
    final snoozed = task.copyWith(
      scheduledAt: DateTime.now().add(Duration(minutes: minutes)),
      status: TaskStatus.snoozed,
    );
    await _db.updateTask(snoozed);
    await ScheduleNotificationService.scheduleTask(snoozed);
    await load();
  }

  Future<void> checkDueTasks() async {
    if (ScheduleNotificationService.shouldSuppressDueChecks()) return;

    final pending = await _db.getAllPendingTasks();
    final now = DateTime.now();
    for (final t in pending) {
      if (!t.triggersAlarm) continue;
      if (ScheduleNotificationService.isTaskAcknowledged(t.id)) continue;
      if (t.scheduledAt.isBefore(now.add(const Duration(seconds: 30))) &&
          t.scheduledAt.isAfter(now.subtract(const Duration(minutes: 2)))) {
        // Marquer comme "en cours de traitement" pour éviter les doublons
        // puis déclencher le callback d'alarme directement (app ouverte)
        ScheduleNotificationService.markImmediateShown(t.id);
        ScheduleNotificationService.onAlarmAction?.call(t, 'open');
        break; // Une alarme à la fois
      }
    }
  }
}
