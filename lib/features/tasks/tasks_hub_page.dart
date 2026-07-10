import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/study_task.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/providers/schedule_provider.dart';
import 'task_format.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/task_action_sheet.dart';
import 'widgets/task_card.dart';

class TasksHubPage extends StatefulWidget {
  const TasksHubPage({super.key, this.openAddOnStart = false});

  /// Si `true`, ouvre automatiquement le sheet d'ajout de tâche au démarrage.
  /// Utilisé quand l'app est lancée depuis le widget "Ajouter une tâche" du bureau.
  final bool openAddOnStart;

  @override
  State<TasksHubPage> createState() => _TasksHubPageState();
}

class _TasksHubPageState extends State<TasksHubPage> {
  int _navIndex = 1;
  DateTime _selectedDay = TaskFormat.dateOnly(DateTime.now());
  final _searchCtrl = TextEditingController();
  String _historyFilter = 'all';

  List<StudyTask> _todayTasks = [];
  List<StudyTask> _historyTasks = [];
  bool _loadingToday = true;
  bool _loadingHistory = true;

  // Cache du groupement historique — recalculé uniquement lorsque _historyTasks change
  Map<String, List<StudyTask>>? _groupedCache;
  List<StudyTask>? _historyTasksForGroup;

  ScheduleProvider? _scheduleProvider;

  // Debounce de la recherche pour éviter des requêtes BDD à chaque frappe
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduleProvider = context.read<ScheduleProvider>();
      _scheduleProvider!.addListener(_onScheduleUpdated);
      // On évite load() complet si le provider est déjà chargé
      if (!_scheduleProvider!.isLoading &&
          _scheduleProvider!.schedules.isEmpty) {
        await _scheduleProvider!.load();
      }
      await _reloadAll();
      // Ouvre le sheet d'ajout si demandé (depuis widget bureau)
      if (widget.openAddOnStart && mounted) {
        final newDate = await showAddTaskSheet(
          context,
          initialDate: _selectedDay,
        );
        if (newDate != null) await _afterTaskSaved(newDate);
      }
    });
  }

  @override
  void dispose() {
    _scheduleProvider?.removeListener(_onScheduleUpdated);
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScheduleUpdated() {
    if (!mounted || _scheduleProvider == null || _scheduleProvider!.isLoading) {
      return;
    }
    final mutationDate = _scheduleProvider!.lastTaskMutationAt;
    if (mutationDate != null &&
        !TaskFormat.isSameDay(mutationDate, _selectedDay)) {
      setState(() => _selectedDay = TaskFormat.dateOnly(mutationDate));
    }
    _reloadAll(silent: true);
  }

  DateTime get _today => TaskFormat.dateOnly(DateTime.now());

  Future<void> _reloadToday({bool silent = false}) async {
    if (!silent) setState(() => _loadingToday = true);
    final tasks = await context.read<ScheduleProvider>().getTasksForDate(
      _selectedDay,
    );
    final studyTasks = tasks
        .where((t) => t.isStudyActivity || t.isManual)
        .toList();
    if (mounted) {
      setState(() {
        _todayTasks = studyTasks;
        _loadingToday = false;
      });
    }
  }

  Future<void> _reloadHistory({bool silent = false}) async {
    if (!silent) setState(() => _loadingHistory = true);
    final filter = switch (_historyFilter) {
      'completed' => TaskHistoryFilter.completed,
      'cancelled' => TaskHistoryFilter.cancelled,
      _ => TaskHistoryFilter.all,
    };
    final tasks = await context.read<ScheduleProvider>().getTaskHistory(
      filter: filter,
      search: _searchCtrl.text,
      beforeDate: _today.subtract(const Duration(days: 1)),
    );
    final studyTasks = tasks
        .where((t) => t.isStudyActivity || t.isManual)
        .toList();
    if (mounted) {
      setState(() {
        _historyTasks = studyTasks;
        _groupedCache = null; // invalidate cache
        _loadingHistory = false;
      });
    }
  }

  Future<void> _reloadAll({bool silent = false}) async {
    await Future.wait([
      _reloadToday(silent: silent),
      // Charge l'historique uniquement si l'onglet est visible ou si pas encore chargé
      if (_navIndex == 0 || _loadingHistory) _reloadHistory(silent: silent),
    ]);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _reloadHistory();
    });
  }

  Future<void> _afterTaskSaved(DateTime? newDate) async {
    if (newDate != null &&
        !TaskFormat.isSameDay(newDate, _selectedDay) &&
        mounted) {
      setState(() => _selectedDay = TaskFormat.dateOnly(newDate));
    }
    await _reloadAll(silent: true);
  }

  Future<void> _selectDay(DateTime day) async {
    setState(() => _selectedDay = day);
    await _reloadToday();
  }

  // Groupement mémoïsé : on recalcule uniquement si la liste a changé
  Map<String, List<StudyTask>> get _grouped {
    if (!identical(_historyTasksForGroup, _historyTasks) ||
        _groupedCache == null) {
      _historyTasksForGroup = _historyTasks;
      final m = <String, List<StudyTask>>{};
      for (final t in _historyTasks) {
        m.putIfAbsent(TaskFormat.longDate(t.scheduledAt), () => []).add(t);
      }
      _groupedCache = m;
    }
    return _groupedCache!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mes tâches',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _navIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                final newDate = await showAddTaskSheet(
                  context,
                  initialDate: _selectedDay,
                );
                if (newDate != null) await _afterTaskSaved(newDate);
              },
              child: const Icon(Icons.add),
            )
          : null,
      // Remplace IndexedStack par un vrai Offstage pour éviter de builder les deux onglets
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: [
                _buildHistoryTab(isDark),
                _buildTodayTab(isDark, primary),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          // Charge l'historique à la demande si pas encore fait
          if (i == 0 && _historyTasks.isEmpty && !_loadingHistory) {
            _reloadHistory();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_rounded),
            label: 'Recent',
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab(bool isDark, Color primary) {
    final done = _todayTasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final pending = _todayTasks.where((t) => t.isPending).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ScheduleProvider>().load();
        await _reloadToday();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        // Calcul du nombre d'items pour la liste virtualisée
        itemCount: _loadingToday
            ? 5 // header + chips + compteur + loader
            : (5 +
                  _todayTasks.length +
                  (pending.isEmpty && _todayTasks.isNotEmpty ? 1 : 0)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                TaskFormat.longDate(_selectedDay),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  _DateChip(
                    label: 'Hier',
                    sub: TaskFormat.shortDate(
                      _today.subtract(const Duration(days: 1)),
                    ),
                    selected: TaskFormat.isSameDay(
                      _selectedDay,
                      _today.subtract(const Duration(days: 1)),
                    ),
                    onTap: () =>
                        _selectDay(_today.subtract(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 10),
                  _DateChip(
                    label: 'Auj.',
                    sub: TaskFormat.shortDate(_today),
                    selected: TaskFormat.isSameDay(_selectedDay, _today),
                    onTap: () => _selectDay(_today),
                  ),
                  const SizedBox(width: 10),
                  _DateChip(
                    label: 'Demain',
                    sub: TaskFormat.shortDate(
                      _today.add(const Duration(days: 1)),
                    ),
                    selected: TaskFormat.isSameDay(
                      _selectedDay,
                      _today.add(const Duration(days: 1)),
                    ),
                    onTap: () =>
                        _selectDay(_today.add(const Duration(days: 1))),
                  ),
                ],
              ),
            );
          }
          if (index == 2) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${_todayTasks.length} tâche${_todayTasks.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$done/${_todayTasks.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }
          if (index == 3) {
            if (_loadingToday) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_todayTasks.isEmpty) {
              return _EmptyTasks(
                onAdd: () async {
                  final newDate = await showAddTaskSheet(
                    context,
                    initialDate: _selectedDay,
                  );
                  if (newDate != null) await _afterTaskSaved(newDate);
                },
              );
            }
            return const SizedBox.shrink();
          }
          // Items de tâche (index 4+)
          final taskIdx = index - 4;
          if (taskIdx < _todayTasks.length) {
            final task = _todayTasks[taskIdx];
            return TaskCard(
              key: ValueKey('${task.id}_${task.scheduledAt.toIso8601String()}'),
              task: task,
              onTap: () async {
                final changed = await showTaskActionSheet(context, task);
                if (changed) await _reloadAll(silent: true);
              },
              onChecked: task.isPending
                  ? (_) =>
                        context.read<ScheduleProvider>().completeTask(task.id)
                  : null,
            );
          }
          // Dernier item : message "tout terminé"
          if (!_loadingToday && pending.isEmpty && _todayTasks.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Toutes les tâches du jour sont terminées 🎉',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final grouped = _grouped;
    final groupKeys = grouped.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tâches d\'avant-hier et plus anciennes',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged, // debounced
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FilterTab(
                label: 'Toutes',
                selected: _historyFilter == 'all',
                onTap: () async {
                  setState(() => _historyFilter = 'all');
                  await _reloadHistory();
                },
              ),
              _FilterTab(
                label: 'Effectuées',
                selected: _historyFilter == 'completed',
                onTap: () async {
                  setState(() => _historyFilter = 'completed');
                  await _reloadHistory();
                },
              ),
              _FilterTab(
                label: 'Annulées',
                selected: _historyFilter == 'cancelled',
                onTap: () async {
                  setState(() => _historyFilter = 'cancelled');
                  await _reloadHistory();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _historyTasks.isEmpty
              ? Center(
                  child: Text(
                    'Aucune tâche antérieure à hier',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await context.read<ScheduleProvider>().load();
                    await _reloadHistory();
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: groupKeys.length,
                    itemBuilder: (context, index) {
                      final dateLabel = groupKeys[index];
                      final dayTasks = grouped[dateLabel]!;
                      return _HistoryGroup(
                        key: ValueKey(dateLabel),
                        dateLabel: dateLabel,
                        tasks: dayTasks,
                        onTaskTap: (task) async {
                          final changed = await showTaskActionSheet(
                            context,
                            task,
                          );
                          if (changed) await _reloadAll(silent: true);
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Widget extrait pour éviter des rebuilds en cascade sur les groupes de l'historique
class _HistoryGroup extends StatelessWidget {
  final String dateLabel;
  final List<StudyTask> tasks;
  final Future<void> Function(StudyTask) onTaskTap;

  const _HistoryGroup({
    super.key,
    required this.dateLabel,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 8),
          child: Text(
            dateLabel,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        ...tasks.map(
          (task) => TaskCard(
            key: ValueKey('${task.id}_${task.scheduledAt.toIso8601String()}'),
            task: task,
            onTap: () => onTaskTap(task),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primary : Colors.grey.shade300,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 36,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTasks({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Aucune tâche ce jour',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez une tâche ou générez un emploi du temps',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une tâche'),
          ),
        ],
      ),
    );
  }
}
