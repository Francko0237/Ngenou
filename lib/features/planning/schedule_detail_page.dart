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

  // Découpage en intervalles stricts de 7 jours
  List<List<DateTime>> get _weeksInPeriod {
    final days = _daysInPeriod;
    if (days.isEmpty) return [];
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      final end = (i + 7 < days.length) ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
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
        title: Text(_schedule.titre),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Exporter en PDF / Imprimer',
            onPressed: _loading ? null : _exportPdf,
          ),
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
                      ),
                    );
                  },
                ),
    );
  }
}

/// Widget représentant une table spatiale complète de 7 jours (style PDF)
class _WeekScheduleTable extends StatelessWidget {
  final int weekIndex;
  final List<DateTime> weekDays;
  final StudySchedule schedule;
  final List<StudyTask> Function(DateTime day) tasksForDay;
  final void Function(StudyTask task) onTaskTap;
  final bool isDark;
  final Color primary;

  const _WeekScheduleTable({
    required this.weekIndex,
    required this.weekDays,
    required this.schedule,
    required this.tasksForDay,
    required this.onTaskTap,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final startDay = weekDays.first;
    final endDay = weekDays.last;
    final allWeekTasks = weekDays.expand((d) => tasksForDay(d)).toList();

    // Déterminer la plage horaire dynamique (entre minHour et maxHour)
    int minHour = 7;
    int maxHour = 21;
    for (final t in allWeekTasks) {
      if (t.scheduledAt.hour < minHour) minHour = t.scheduledAt.hour;
      final endH =
          t.scheduledAt.add(Duration(minutes: t.durationMinutes)).hour;
      if (endH > maxHour) maxHour = (endH <= 23 ? endH : 23);
    }
    final hourRowsCount = (maxHour - minHour) + 1;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMuted = isDark ? Colors.grey[400] : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── En-tête de la semaine (Semaine X + Plage de dates) ───────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF252525)
                  : primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Semaine ${weekIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Du ${TaskFormat.shortDate(startDay)} au ${TaskFormat.shortDate(endDay)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      Text(
                        '${allWeekTasks.length} créneaux planifiés cette semaine',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Grille Spatiale (7 Jours x Heures) avec défilement horizontal ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne d'en-tête (Colonnes des jours)
                  Row(
                    children: [
                      // Colonne heure
                      _headerCell(
                        text: 'Heure',
                        width: 65,
                        isDark: isDark,
                        borderColor: borderColor,
                        isAxis: true,
                      ),
                      // 7 colonnes pour les jours
                      ...weekDays.map((d) {
                        final isToday =
                            TaskFormat.isSameDay(d, DateTime.now());
                        return _dayHeaderCell(
                          day: d,
                          width: 135,
                          isToday: isToday,
                          primary: primary,
                          isDark: isDark,
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
                        // Cellule heure (Axe vertical)
                        _timeCell(
                          hour: hour,
                          width: 65,
                          height: 72,
                          isDark: isDark,
                          borderColor: borderColor,
                        ),
                        // 7 cellules pour chaque jour
                        ...weekDays.map((d) {
                          final dayTasks = tasksForDay(d);
                          final hourTasks = dayTasks
                              .where((t) => t.scheduledAt.hour == hour)
                              .toList();
                          return _dayHourCell(
                            context: context,
                            tasks: hourTasks,
                            width: 135,
                            height: 72,
                            isDark: isDark,
                            borderColor: borderColor,
                            onTaskTap: onTaskTap,
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell({
    required String text,
    required double width,
    required bool isDark,
    required Color borderColor,
    bool isAxis = false,
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF232323)
            : const Color(0xFFF1F5F9),
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
        color: isDark
            ? const Color(0xFF1B1B1B)
            : const Color(0xFFF8FAFC),
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
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
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
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: isDark ? 0.28 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(color: accent, width: 3.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.displayTitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
                                const Icon(
                                  Icons.check_circle,
                                  size: 11,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                          Text(
                            '${TaskFormat.time(task.scheduledAt)} (${task.durationMinutes}m)',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
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
