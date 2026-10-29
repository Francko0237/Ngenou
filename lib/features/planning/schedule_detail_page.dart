import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
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
  late StudySchedule _schedule;
  ScheduleProvider? _scheduleProvider;

  // ScrollController pour bloquer le scroll quand l'utilisateur interagit avec un tableau
  final ScrollController _listScrollController = ScrollController();
  bool _tableGestureLocked = false;

  // Cache des jours de la période
  List<DateTime>? _daysCache;
  StudySchedule? _scheduleForCache;

  // Cache du mapping jour → tâches
  Map<String, List<StudyTask>>? _tasksByDay;
  List<StudyTask>? _tasksForCache;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduleProvider = context.read<ScheduleProvider>();
      _scheduleProvider!.addListener(_onScheduleUpdated);
      await _load();
    });
  }

  @override
  void dispose() {
    _scheduleProvider?.removeListener(_onScheduleUpdated);
    _listScrollController.dispose();
    super.dispose();
  }

  void _onScheduleUpdated() {
    if (!mounted || _scheduleProvider == null || _scheduleProvider!.isLoading) {
      return;
    }
    _load();
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleWizardPage(scheduleToEdit: _schedule),
      ),
    );
    if (!mounted || changed != true) return;
    final provider = context.read<ScheduleProvider>();
    await provider.load();
    if (!mounted) return;
    final updated = await provider.getScheduleById(_schedule.id);
    if (updated != null && mounted) {
      setState(() => _schedule = updated);
      await _load();
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

  // Getter mémoïsé : liste de tous les jours de la période
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

  // Découpage en semaines ISO (Lundi → Dimanche)
  List<List<DateTime>> get _weeksInPeriod {
    final days = _daysInPeriod;
    if (days.isEmpty) return [];

    // Trouver le Lundi de la semaine du premier jour
    final firstDay = days.first;
    // weekday: 1=Lun … 7=Dim
    final mondayOffset = (firstDay.weekday - 1);
    var monday = firstDay.subtract(Duration(days: mondayOffset));

    // Trouver le Dimanche de la semaine du dernier jour
    final lastDay = days.last;
    final sundayOffset = (7 - lastDay.weekday) % 7;
    final sunday = lastDay.add(Duration(days: sundayOffset));

    final weeks = <List<DateTime>>[];
    var cursor = monday;
    while (!cursor.isAfter(sunday)) {
      final week = <DateTime>[];
      for (var i = 0; i < 7; i++) {
        week.add(cursor.add(Duration(days: i)));
      }
      weeks.add(week);
      cursor = cursor.add(const Duration(days: 7));
    }
    return weeks;
  }

  // Index mémoïsé O(1) : jour -> tâches
  Map<String, List<StudyTask>> get _tasksByDayMap {
    if (!identical(_tasksForCache, _tasks) || _tasksByDay == null) {
      _tasksForCache = _tasks;
      final m = <String, List<StudyTask>>{};
      for (final t in _tasks) {
        final key = TaskFormat.dateOnly(t.scheduledAt).toIso8601String();
        m.putIfAbsent(key, () => []).add(t);
      }
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

  Future<void> _toggleTaskStatus(StudyTask task) async {
    if (task.status == TaskStatus.completed) {
      final updated = task.copyWith(status: TaskStatus.pending);
      await DatabaseHelper.instance.updateTask(updated);
      if (mounted) await context.read<ScheduleProvider>().load();
    } else {
      if (mounted) {
        await context.read<ScheduleProvider>().completeTask(task.id);
      }
    }
    await _load();
  }

  void _showTaskDetailDialog(StudyTask task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = activityColor(
      task.activityType,
      matiereId: task.matiereId,
      context: context,
    );
    final isDone = task.status == TaskStatus.completed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.25 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activityIcon(task.activityType, task.matiereId),
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.displayTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activitySubtitle(task.activityType)} • ${task.durationMinutes} min',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: TaskFormat.longDate(task.scheduledAt),
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _detailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Horaire',
                      value: TaskFormat.timeRange(
                        task.scheduledAt,
                        task.durationMinutes,
                      ),
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _detailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Statut',
                      value: isDone ? 'Terminé' : 'À faire',
                      isDark: isDark,
                      valueColor: isDone ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _toggleTaskStatus(task);
                      },
                      icon: Icon(
                        isDone
                            ? Icons.replay_rounded
                            : Icons.check_circle_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        isDone ? 'Remettre en cours' : 'Marquer comme fait',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDone ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (task.isStudyActivity &&
                      task.matiereId != StudyTask.lifeRhythmMatiereId) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/cours/${task.matiereId}');
                      },
                      icon: const Icon(Icons.school_rounded, color: Colors.white),
                      label: const Text(
                        'Ouvrir cours',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // Impression / Export PDF du tableau spatial complet
  Future<void> _exportPdf() async {
    final weeks = _weeksInPeriod;
    final pdf = pw.Document();

    for (var wIdx = 0; wIdx < weeks.length; wIdx++) {
      final weekDays = weeks[wIdx];
      final startStr = TaskFormat.shortDate(weekDays.first);
      final endStr = TaskFormat.shortDate(weekDays.last);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${_schedule.titre} — Semaine ${wIdx + 1} ($startStr au $endStr)',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Ngenou • Planning d\'apprentissage',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    children: [
                      // Header jours
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('Heure', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          ),
                          ...weekDays.map((d) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                '${TaskFormat.weekdayShort(d)}\n${d.day}/${d.month}',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                              ),
                            );
                          }),
                        ],
                      ),
                      // Lignes horaires de 07h à 21h
                      ...List.generate(15, (hIdx) {
                        final hour = 7 + hIdx;
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                              ),
                            ),
                            ...weekDays.map((d) {
                              final dayTasks = _tasksForDay(d);
                              final hourTasks = dayTasks.where((t) => t.scheduledAt.hour == hour).toList();
                              if (hourTasks.isEmpty) {
                                return pw.Container(height: 24);
                              }
                              return pw.Container(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: hourTasks.map((t) {
                                    return pw.Text(
                                      '• ${t.displayTitle} (${TaskFormat.time(t.scheduledAt)})',
                                      style: const pw.TextStyle(fontSize: 7),
                                      maxLines: 2,
                                    );
                                  }).toList(),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'emploi_du_temps_${_schedule.titre.replaceAll(' ', '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = _weeksInPeriod;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          _schedule.titre,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Exporter en PDF / Imprimer',
            onPressed: _loading ? null : _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Modifier',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : weeks.isEmpty
              ? Center(
                  child: Text(
                    'Aucune période définie dans cet emploi du temps',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _listScrollController,
                  physics: _tableGestureLocked
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                  itemCount: weeks.length,
                  itemBuilder: (context, weekIdx) {
                    final weekDays = weeks[weekIdx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _WeekScheduleTable(
                        weekIndex: weekIdx,
                        weekDays: weekDays,
                        schedule: _schedule,
                        tasksForDay: _tasksForDay,
                        onTaskTap: _showTaskDetailDialog,
                        isDark: isDark,
                        primary: primary,
                        onScrollLockChange: (locked) {
                          if (_tableGestureLocked != locked) {
                            setState(() => _tableGestureLocked = locked);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// Widget représentant une table spatiale complète de 7 jours (style PDF) avec Zoom interactif
class _WeekScheduleTable extends StatefulWidget {
  final int weekIndex;
  final List<DateTime> weekDays;
  final StudySchedule schedule;
  final List<StudyTask> Function(DateTime day) tasksForDay;
  final void Function(StudyTask task) onTaskTap;
  final bool isDark;
  final Color primary;
  final void Function(bool locked) onScrollLockChange;

  const _WeekScheduleTable({
    required this.weekIndex,
    required this.weekDays,
    required this.schedule,
    required this.tasksForDay,
    required this.onTaskTap,
    required this.isDark,
    required this.primary,
    required this.onScrollLockChange,
  });

  @override
  State<_WeekScheduleTable> createState() => _WeekScheduleTableState();
}

class _WeekScheduleTableState extends State<_WeekScheduleTable> {
  late final TransformationController _transController;
  double _currentScale = 1.0;
  bool _initializedFit = false;
  Size _viewportSize = Size.zero;

  static const double _hourColWidth = 65.0;
  static const double _dayColWidth = 135.0;
  static const double _hourRowHeight = 78.0;

  @override
  void initState() {
    super.initState();
    _transController = TransformationController();
    _transController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transController.removeListener(_onTransformChanged);
    _transController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02) {
      if (mounted) {
        setState(() {
          _currentScale = scale;
        });
      }
    }
  }

  void _zoom(double factor) {
    final currentScale = _transController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.25, 3.0);
    final actualFactor = newScale / currentScale;
    if ((actualFactor - 1.0).abs() < 0.001) return;

    final focalPoint = Offset(
      _viewportSize.width > 0 ? _viewportSize.width / 2 : 180,
      _viewportSize.height > 0 ? _viewportSize.height / 2 : 240,
    );

    final scenePointBefore = _transController.toScene(focalPoint);

    final matrix = _transController.value.clone();
    matrix.scaleByDouble(actualFactor, actualFactor, 1.0, 1.0);
    _transController.value = matrix;

    final scenePointAfter = _transController.toScene(focalPoint);
    final dx = scenePointAfter.dx - scenePointBefore.dx;
    final dy = scenePointAfter.dy - scenePointBefore.dy;

    matrix.translateByDouble(dx, dy, 0.0, 1.0);
    _transController.value = matrix;

    setState(() {
      _currentScale = newScale;
    });
  }

  void _fitToWidth(double availableWidth, double tableWidth) {
    final targetScale = (availableWidth / tableWidth).clamp(0.25, 1.0);
    setState(() {
      _transController.value =
          Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
      _currentScale = targetScale;
    });
  }

  void _resetZoom() {
    setState(() {
      _transController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }


  void _openFullscreen(
    BuildContext context,
    double tableWidth,
    int minHour,
    int hourRowsCount,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullscreenSchedulePage(
          weekIndex: widget.weekIndex,
          weekDays: widget.weekDays,
          schedule: widget.schedule,
          tasksForDay: widget.tasksForDay,
          onTaskTap: widget.onTaskTap,
          isDark: widget.isDark,
          primary: widget.primary,
          minHour: minHour,
          hourRowsCount: hourRowsCount,
          tableWidth: tableWidth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDay = widget.weekDays.first;
    final endDay = widget.weekDays.last;
    final allWeekTasks = widget.weekDays.expand((d) => widget.tasksForDay(d)).toList();

    // Déterminer la plage horaire dynamique (entre minHour et maxHour)
    int minHour = 7;
    int maxHour = 21;
    for (final t in allWeekTasks) {
      if (t.scheduledAt.hour < minHour) minHour = t.scheduledAt.hour;
      final endH = t.scheduledAt.add(Duration(minutes: t.durationMinutes)).hour;
      if (endH > maxHour) maxHour = (endH <= 23 ? endH : 23);
    }
    final hourRowsCount = (maxHour - minHour) + 1;
    final tableWidth = _hourColWidth + (widget.weekDays.length * _dayColWidth) + 24.0;

    final cardBg = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        widget.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0);
    final textMain = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final textMuted =
        widget.isDark ? Colors.grey[400] : const Color(0xFF64748B);

    final screenHeight = MediaQuery.of(context).size.height;
    final containerHeight = (screenHeight * 0.58).clamp(420.0, 580.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        _viewportSize = Size(availableWidth, containerHeight);

        // Auto-fit initial pour que la semaine entière soit immédiatement visible
        if (!_initializedFit && availableWidth > 0) {
          _initializedFit = true;
          final initialScale = (availableWidth / tableWidth).clamp(0.28, 0.95);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _transController.value =
                    Matrix4.diagonal3Values(initialScale, initialScale, 1.0);
                _currentScale = initialScale;
              });
            }
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── En-tête de la semaine + Barre d'outils Zoom ───────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF252525)
                      : widget.primary.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Semaine ${widget.weekIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Du ${TaskFormat.shortDate(startDay)} au ${TaskFormat.shortDate(endDay)}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                '${allWeekTasks.length} créneaux planifiés',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ─── Barre de contrôle du Zoom ─────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.black26
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Bouton Dézoomer (-)
                          _zoomIconBtn(
                            Icons.remove_circle_outline_rounded,
                            () => _zoom(0.8),
                            tooltip: 'Dézoomer',
                          ),
                          const SizedBox(width: 4),
                          // Badge pourcentage (statique, pas d'onTap parasite)
                          Container(
                            constraints: const BoxConstraints(minWidth: 46),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(_currentScale * 100).toInt()}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: widget.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Bouton Zoomer (+)
                          _zoomIconBtn(
                            Icons.add_circle_outline_rounded,
                            () => _zoom(1.25),
                            tooltip: 'Zoomer',
                          ),
                          const Spacer(),
                          // Séparateur
                          Container(width: 1, height: 20, color: borderColor),
                          const SizedBox(width: 4),
                          // Bouton Ajuster
                          _zoomIconBtn(
                            Icons.fit_screen_rounded,
                            () => _fitToWidth(availableWidth, tableWidth),
                            color: widget.primary,
                            tooltip: 'Ajuster à l\'écran',
                          ),
                          // Bouton reset 100%
                          _zoomIconBtn(
                            Icons.crop_free_rounded,
                            _resetZoom,
                            color: textMuted ?? Colors.grey,
                            tooltip: 'Taille 100%',
                          ),
                          // Bouton Plein Écran
                          _zoomIconBtn(
                            Icons.open_in_full_rounded,
                            () => _openFullscreen(
                              context,
                              tableWidth,
                              minHour,
                              hourRowsCount,
                            ),
                            color: widget.primary,
                            tooltip: 'Plein écran',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Mini guide d'interaction ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: widget.isDark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pincez pour zoomer • Glissez pour explorer • 2x tap pour basculer',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Grille Spatiale Zoomable & Déplaçable (InteractiveViewer) ─
              // Le Listener capture les pointer events pour bloquer le scroll
              // de la ListView parente pendant que l'utilisateur interagit ici.
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => widget.onScrollLockChange(true),
                onPointerUp: (_) => widget.onScrollLockChange(false),
                onPointerCancel: (_) => widget.onScrollLockChange(false),
                child: SizedBox(
                height: containerHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: InteractiveViewer(
                    transformationController: _transController,
                    constrained: false,
                    // Pas de boundaryMargin pour éviter de bloquer le pan
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.20,
                    maxScale: 3.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    clipBehavior: Clip.none,
                    child: SizedBox(
                        width: tableWidth,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ligne d'en-tête (Colonnes des jours)
                              Row(
                                children: [
                                  _headerCell(
                                    text: 'Heure',
                                    width: _hourColWidth,
                                    isDark: widget.isDark,
                                    borderColor: borderColor,
                                  ),
                                  ...widget.weekDays.map((d) {
                                    final isToday =
                                        TaskFormat.isSameDay(d, DateTime.now());
                                    return _dayHeaderCell(
                                      day: d,
                                      width: _dayColWidth,
                                      isToday: isToday,
                                      primary: widget.primary,
                                      isDark: widget.isDark,
                                      borderColor: borderColor,
                                    );
                                  }),
                                ],
                              ),

                              // Lignes des heures
                              ...List.generate(hourRowsCount, (rowIdx) {
                                final hour = minHour + rowIdx;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _timeCell(
                                      hour: hour,
                                      width: _hourColWidth,
                                      height: _hourRowHeight,
                                      isDark: widget.isDark,
                                      borderColor: borderColor,
                                    ),
                                    ...widget.weekDays.map((d) {
                                      final dayTasks = widget.tasksForDay(d);
                                      final hourTasks = dayTasks
                                          .where((t) => t.scheduledAt.hour == hour)
                                          .toList();
                                      return _dayHourCell(
                                        context: context,
                                        tasks: hourTasks,
                                        width: _dayColWidth,
                                        height: _hourRowHeight,
                                        isDark: widget.isDark,
                                        borderColor: borderColor,
                                        onTaskTap: widget.onTaskTap,
                                      );
                                    }),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),  // SizedBox (InteractiveViewer child)
                    ),  // InteractiveViewer
                  ),  // ClipRRect
                ),  // SizedBox (height)
              ),  // Listener (scroll lock)
            ],
            ),
          );
        },
      );
  }

  Widget _zoomIconBtn(
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }

  Widget _headerCell({
    required String text,
    required double width,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : const Color(0xFFF1F5F9),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey[400] : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _dayHeaderCell({
    required DateTime day,
    required double width,
    required bool isToday,
    required Color primary,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
            : (isDark ? const Color(0xFF232323) : const Color(0xFFF8FAFC)),
        border: Border.all(
          color: isToday ? primary : borderColor,
          width: isToday ? 1.5 : 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            TaskFormat.weekdayShort(day).split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? primary
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
          Text(
            '${day.day} ${TaskFormat.shortDate(day).split(' ').last}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isToday
                  ? primary
                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeCell({
    required int hour,
    required double width,
    required double height,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF8FAFC),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        '${hour.toString().padLeft(2, '0')}:00',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[400] : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _dayHourCell({
    required BuildContext context,
    required List<StudyTask> tasks,
    required double width,
    required double height,
    required bool isDark,
    required Color borderColor,
    required void Function(StudyTask task) onTaskTap,
  }) {
    final isMulti = tasks.length >= 2;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: 3,
        vertical: isMulti ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: tasks.isEmpty
          ? const SizedBox()
          : SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: tasks.map((task) {
                  final isDone = task.status == TaskStatus.completed;
                  final accent = activityColor(
                    task.activityType,
                    matiereId: task.matiereId,
                    context: context,
                  );

                  return InkWell(
                    onTap: () => onTaskTap(task),
                    borderRadius: BorderRadius.circular(isMulti ? 5 : 6),
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: isMulti ? 1.5 : 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMulti ? 4 : 5,
                        vertical: isMulti ? 2.5 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: isDark ? 0.28 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(isMulti ? 5 : 6),
                        border: Border(
                          left: BorderSide(
                            color: accent,
                            width: isMulti ? 3.0 : 3.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.displayTitle,
                                  style: TextStyle(
                                    fontSize: isMulti ? 10.0 : 11.0,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDone
                                        ? Colors.grey
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDone)
                                Icon(
                                  Icons.check_circle,
                                  size: isMulti ? 10 : 11,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${TaskFormat.time(task.scheduledAt)} (${task.durationMinutes}m)',
                            style: TextStyle(
                              fontSize: isMulti ? 8.5 : 9.5,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: isDark
                                  ? Colors.grey[300]
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

/// Page immersive Plein Écran pour explorer la grille spatiale en toute liberté
class _FullscreenSchedulePage extends StatefulWidget {
  final int weekIndex;
  final List<DateTime> weekDays;
  final StudySchedule schedule;
  final List<StudyTask> Function(DateTime day) tasksForDay;
  final void Function(StudyTask task) onTaskTap;
  final bool isDark;
  final Color primary;
  final int minHour;
  final int hourRowsCount;
  final double tableWidth;

  const _FullscreenSchedulePage({
    required this.weekIndex,
    required this.weekDays,
    required this.schedule,
    required this.tasksForDay,
    required this.onTaskTap,
    required this.isDark,
    required this.primary,
    required this.minHour,
    required this.hourRowsCount,
    required this.tableWidth,
  });

  @override
  State<_FullscreenSchedulePage> createState() =>
      _FullscreenSchedulePageState();
}

class _FullscreenSchedulePageState extends State<_FullscreenSchedulePage> {
  static const double _hourColWidth = 65.0;
  static const double _dayColWidth = 135.0;
  static const double _hourRowHeight = 78.0;
  static const double _horizontalPadding = 16.0;

  double get _calculatedTableWidth =>
      _hourColWidth +
      (widget.weekDays.length * _dayColWidth) +
      (_horizontalPadding * 2);

  late final TransformationController _controller;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(() {
      final s = _controller.value.getMaxScaleOnAxis();
      if ((s - _scale).abs() > 0.02) {
        if (mounted) setState(() => _scale = s);
      }
    });

    // Auto-fit plein écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final target = (size.width / _calculatedTableWidth).clamp(0.25, 1.2);
      setState(() {
        _controller.value = Matrix4.diagonal3Values(target, target, 1.0);
        _scale = target;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(0.25, 3.5);
    final actualFactor = nextScale / currentScale;
    if ((actualFactor - 1.0).abs() < 0.001) return;

    final size = MediaQuery.of(context).size;
    final focalPoint = Offset(size.width / 2, size.height / 2);

    final scenePointBefore = _controller.toScene(focalPoint);

    final matrix = _controller.value.clone();
    matrix.scaleByDouble(actualFactor, actualFactor, 1.0, 1.0);
    _controller.value = matrix;

    final scenePointAfter = _controller.toScene(focalPoint);
    final dx = scenePointAfter.dx - scenePointBefore.dx;
    final dy = scenePointAfter.dy - scenePointBefore.dy;

    matrix.translateByDouble(dx, dy, 0.0, 1.0);
    _controller.value = matrix;

    setState(() {
      _scale = nextScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startDay = widget.weekDays.first;
    final endDay = widget.weekDays.last;
    final borderColor =
        widget.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor:
          widget.isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          'Semaine ${widget.weekIndex + 1} (${TaskFormat.shortDate(startDay)} - ${TaskFormat.shortDate(endDay)})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor:
            widget.isDark ? const Color(0xFF1E1E1E) : widget.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
            tooltip: 'Dézoomer',
            onPressed: () => _zoom(0.8),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            child: Text(
              '${(_scale * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
            tooltip: 'Zoomer',
            onPressed: () => _zoom(1.25),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded, color: Colors.white),
            tooltip: 'Ajuster',
            onPressed: () {
              final size = MediaQuery.of(context).size;
              final target =
                  (size.width / _calculatedTableWidth).clamp(0.25, 1.2);
              setState(() {
                _controller.value =
                    Matrix4.diagonal3Values(target, target, 1.0);
                _scale = target;
              });
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        transformationController: _controller,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.2,
        maxScale: 3.5,
        panEnabled: true,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        child: SizedBox(
          width: _calculatedTableWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête des jours
                Row(
                  children: [
                    Container(
                      width: _hourColWidth,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF232323)
                            : const Color(0xFFF1F5F9),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Text(
                        'Heure',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    ...widget.weekDays.map((d) {
                      final isToday = TaskFormat.isSameDay(d, DateTime.now());
                      return Container(
                        width: _dayColWidth,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday
                              ? widget.primary
                                  .withValues(alpha: widget.isDark ? 0.25 : 0.12)
                              : (widget.isDark
                                  ? const Color(0xFF232323)
                                  : const Color(0xFFF8FAFC)),
                          border: Border.all(
                            color: isToday ? widget.primary : borderColor,
                            width: isToday ? 1.5 : 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              TaskFormat.weekdayShort(d).split(' ').first,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? widget.primary
                                    : (widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                              ),
                            ),
                            Text(
                              '${d.day} ${TaskFormat.shortDate(d).split(' ').last}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? widget.primary
                                    : (widget.isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                // Lignes horaires
                ...List.generate(widget.hourRowsCount, (rowIdx) {
                  final hour = widget.minHour + rowIdx;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: _hourColWidth,
                        height: _hourRowHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xFF1B1B1B)
                              : const Color(0xFFF8FAFC),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      ...widget.weekDays.map((d) {
                        final dayTasks = widget.tasksForDay(d);
                        final hourTasks = dayTasks
                            .where((t) => t.scheduledAt.hour == hour)
                            .toList();
                        final isMulti = hourTasks.length >= 2;

                        return Container(
                          width: _dayColWidth,
                          height: _hourRowHeight,
                          padding: EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: isMulti ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          child: hourTasks.isEmpty
                              ? const SizedBox()
                              : SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Column(
                                    children: hourTasks.map((task) {
                                      final isDone =
                                          task.status == TaskStatus.completed;
                                      final accent = activityColor(
                                        task.activityType,
                                        matiereId: task.matiereId,
                                        context: context,
                                      );

                                      return InkWell(
                                        onTap: () => widget.onTaskTap(task),
                                        borderRadius: BorderRadius.circular(isMulti ? 5 : 6),
                                        child: Container(
                                          width: double.infinity,
                                          margin: EdgeInsets.only(
                                            bottom: isMulti ? 1.5 : 2,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMulti ? 4 : 5,
                                            vertical: isMulti ? 2.5 : 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(
                                              alpha: widget.isDark ? 0.28 : 0.15,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(isMulti ? 5 : 6),
                                            border: Border(
                                              left: BorderSide(
                                                color: accent,
                                                width: isMulti ? 3.0 : 3.5,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      task.displayTitle,
                                                      style: TextStyle(
                                                        fontSize: isMulti ? 10.0 : 11.0,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.15,
                                                        decoration: isDone
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                        color: isDone
                                                            ? Colors.grey
                                                            : (widget.isDark
                                                                ? Colors.white
                                                                : Colors
                                                                    .black87),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isDone)
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: isMulti ? 10 : 11,
                                                      color: Colors.green,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                '${TaskFormat.time(task.scheduledAt)} (${task.durationMinutes}m)',
                                                style: TextStyle(
                                                  fontSize: isMulti ? 8.5 : 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.15,
                                                  color: widget.isDark
                                                      ? Colors.grey[300]
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

