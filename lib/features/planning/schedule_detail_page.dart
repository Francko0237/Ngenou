import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/study_schedule.dart';
import '../../../core/models/study_task.dart';
import '../../../core/providers/schedule_provider.dart';
import '../tasks/task_format.dart';
import 'schedule_wizard_page.dart';

class ScheduleDetailPage extends StatefulWidget {
  final StudySchedule schedule;

  const ScheduleDetailPage({super.key, required this.schedule});

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  List<StudyTask> _tasks = [];
  bool _loading = true;
  late DateTime _selectedDay;
  late StudySchedule _schedule;
  late PageController _pageController;
  final _dayStripController = ScrollController();
  ScheduleProvider? _scheduleProvider;

  // Cache des jours de la période — recalculé uniquement quand _schedule change
  List<DateTime>? _daysCache;
  StudySchedule? _scheduleForCache;

  // Cache du mapping jour → tâches — recalculé uniquement quand _tasks change
  Map<String, List<StudyTask>>? _tasksByDay;
  List<StudyTask>? _tasksForCache;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _selectedDay = _initialSelectedDay();
    _pageController = PageController(initialPage: _dayIndexFor(_selectedDay));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduleProvider = context.read<ScheduleProvider>();
      _scheduleProvider!.addListener(_onScheduleUpdated);
      await _load();
      if (mounted) _scrollDayStripToIndex(_dayIndexFor(_selectedDay));
    });
  }

  @override
  void dispose() {
    _scheduleProvider?.removeListener(_onScheduleUpdated);
    _pageController.dispose();
    _dayStripController.dispose();
    super.dispose();
  }

  void _onScheduleUpdated() {
    if (!mounted || _scheduleProvider == null || _scheduleProvider!.isLoading) return;
    _load();
  }

  DateTime _initialSelectedDay() {
    final days = _daysInPeriod;
    if (days.isEmpty) return StudySchedule.dateOnly(_schedule.periodStart);
    final today = TaskFormat.dateOnly(DateTime.now());
    final todayIdx = days.indexWhere((d) => TaskFormat.isSameDay(d, today));
    return todayIdx >= 0 ? days[todayIdx] : days.first;
  }

  int _dayIndexFor(DateTime day) {
    final idx = _daysInPeriod.indexWhere((d) => TaskFormat.isSameDay(d, day));
    return idx >= 0 ? idx : 0;
  }

  void _syncPageController({DateTime? day}) {
    final days = _daysInPeriod;
    if (days.isEmpty) return;
    final targetDay = day ?? _selectedDay;
    var index = _dayIndexFor(targetDay);
    if (index >= days.length) index = days.length - 1;
    _selectedDay = days[index];
    _pageController.dispose();
    _pageController = PageController(initialPage: index);
  }

  void _selectDay(int index) {
    if (index < 0 || index >= _daysInPeriod.length) return;
    setState(() => _selectedDay = _daysInPeriod[index]);
    if (_pageController.hasClients && _pageController.page?.round() != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    _scrollDayStripToIndex(index);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _daysInPeriod.length) return;
    setState(() => _selectedDay = _daysInPeriod[index]);
    _scrollDayStripToIndex(index);
  }

  void _scrollDayStripToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dayStripController.hasClients) return;
      const chipWidth = 78.0;
      final target = (index * chipWidth - 40).clamp(
        0.0,
        _dayStripController.position.maxScrollExtent,
      );
      _dayStripController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleWizardPage(scheduleToEdit: _schedule),
      ),
    );
    if (!mounted || changed != true) return;
    await context.read<ScheduleProvider>().load();
    final updated = await context.read<ScheduleProvider>().getScheduleById(_schedule.id);
    if (updated != null && mounted) {
      setState(() => _schedule = updated);
      _syncPageController();
      await _load();
      _scrollDayStripToIndex(_dayIndexFor(_selectedDay));
    }
  }

  Future<void> _load() async {
    final tasks =
        await context.read<ScheduleProvider>().getTasksForSchedule(_schedule.id);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    }
  }

  // Getter mémoïsé : boucle while exécutée une seule fois par session/schedule
  List<DateTime> get _daysInPeriod {
    if (!identical(_scheduleForCache, _schedule) || _daysCache == null) {
      _scheduleForCache = _schedule;
      final days = <DateTime>[];
      var d = StudySchedule.dateOnly(_schedule.periodStart);
      final end = StudySchedule.dateOnly(_schedule.periodEnd);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
      _daysCache = days;
    }
    return _daysCache!;
  }

  // Index mémoïsé O(1) : construit le mapping une seule fois quand _tasks change
  Map<String, List<StudyTask>> get _tasksByDayMap {
    if (!identical(_tasksForCache, _tasks) || _tasksByDay == null) {
      _tasksForCache = _tasks;
      final m = <String, List<StudyTask>>{};
      for (final t in _tasks) {
        final key = TaskFormat.dateOnly(t.scheduledAt).toIso8601String();
        m.putIfAbsent(key, () => []).add(t);
      }
      // Trie chaque liste par heure une seule fois
      for (final list in m.values) {
        list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      }
      _tasksByDay = m;
    }
    return _tasksByDay!;
  }

  List<StudyTask> _tasksForDay(DateTime day) {
    final key = TaskFormat.dateOnly(day).toIso8601String();
    return _tasksByDayMap[key] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final days = _daysInPeriod;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_schedule.titre),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Modifier',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DayStrip(
                        controller: _dayStripController,
                        days: days,
                        selectedDay: _selectedDay,
                        primary: primary,
                        isDark: isDark,
                        onSelectDay: _selectDay,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              TaskFormat.longDate(_selectedDay),
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                           
                         
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: days.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune journée dans cette période',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: days.length,
                          itemBuilder: (context, index) {
                            final day = days[index];
                            final dayTasks = _tasksForDay(day);
                            if (dayTasks.isEmpty) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.35,
                                    child: Center(
                                      child: Text(
                                        'Aucun créneau ce jour',
                                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: dayTasks.length,
                              itemBuilder: (context, i) {
                                final task = dayTasks[i];
                                return _TimelineTaskCard(
                                  key: ValueKey(
                                    '${task.id}_${task.scheduledAt.toIso8601String()}',
                                  ),
                                  task: task,
                                  onComplete: () async {
                                    await context
                                        .read<ScheduleProvider>()
                                        .completeTask(task.id);
                                    await _load();
                                  },
                                  onOpen: task.isStudyActivity &&
                                          task.isPending &&
                                          task.matiereId != StudyTask.lifeRhythmMatiereId
                                      ? () => context.push('/cours/${task.matiereId}')
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TimelineTaskCard extends StatelessWidget {
  final StudyTask task;
  final VoidCallback onComplete;
  final VoidCallback? onOpen;

  const _TimelineTaskCard({
    super.key,
    required this.task,
    required this.onComplete,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = task.status == TaskStatus.completed;
    final isCancelled = task.status == TaskStatus.cancelled;
    final isStudy = task.isStudyActivity;
    final accent = activityColor(task.activityType, matiereId: task.matiereId, context: context);
    final bg = isStudy
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        : (isDark ? const Color(0xFF161616) : accent.withValues(alpha: 0.06));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: isStudy
                ? (isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null)
                : Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.25)),
            boxShadow: isStudy
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 88,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(activityIcon(task.activityType, task.matiereId), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.displayTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          decoration: isStudy && (isDone || isCancelled)
                              ? TextDecoration.lineThrough
                              : null,
                          color: isStudy && (isDone || isCancelled)
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${activitySubtitle(task.activityType)} · ${TaskFormat.timeRange(task.scheduledAt, task.durationMinutes)}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isStudy && isDone)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.check_circle, color: Colors.green),
                )
              else if (isStudy && task.isPending)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: onComplete,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day-strip extrait en StatelessWidget pour éviter de reconstruire tous les chips
/// à chaque changement de page ou scroll.
class _DayStrip extends StatelessWidget {
  final ScrollController controller;
  final List<DateTime> days;
  final DateTime selectedDay;
  final Color primary;
  final bool isDark;
  final void Function(int index) onSelectDay;

  const _DayStrip({
    required this.controller,
    required this.days,
    required this.selectedDay,
    required this.primary,
    required this.isDark,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(days.length, (index) {
          final day = days[index];
          final selected = TaskFormat.isSameDay(day, selectedDay);
          return _DayChip(
            key: ValueKey(day.toIso8601String()),
            day: day,
            selected: selected,
            primary: primary,
            isDark: isDark,
            onTap: () => onSelectDay(index),
          );
        }),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _DayChip({
    super.key,
    required this.day,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? (isDark ? Colors.white : primary)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            TaskFormat.weekdayShort(day),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected
                  ? (isDark ? Colors.white : primary)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }
}

