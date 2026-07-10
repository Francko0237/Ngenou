import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/schedule_subject.dart';
import '../../../core/models/week_occupancy.dart';
import '../../../core/models/projet.dart';
import '../../../core/models/study_schedule.dart';
import '../../../core/providers/projets_provider.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/services/schedule_notification_service.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../modules/modules_registry.dart';
import '../../../core/utils/duration_utils.dart';

class ScheduleWizardPage extends StatefulWidget {
  final StudySchedule? scheduleToEdit;

  const ScheduleWizardPage({super.key, this.scheduleToEdit});

  @override
  State<ScheduleWizardPage> createState() => _ScheduleWizardPageState();
}

class _ScheduleWizardPageState extends State<ScheduleWizardPage> {
  final _pageController = PageController();
  late final TextEditingController _titreCtrl;
  int _step = 0;
  bool _generating = false;
  bool _regenerateTasks = true;

  final Map<String, ScheduleSubject> _selected = {};
  final Set<String> _selectedProjectIds = {};
  late WeekOccupancy _occupancy;
  late DateTime _periodStart;
  late DateTime _periodEnd;

  bool get _isEditing => widget.scheduleToEdit != null;

  String get _periodRangeLabel =>
      StudySchedule.dateRangeLabel(_periodStart, _periodEnd);

  static String formatDuration(int minutes) => DurationUtils.format(minutes);

  @override
  void initState() {
    super.initState();
    final existing = widget.scheduleToEdit;
    if (existing != null) {
      _titreCtrl = TextEditingController(text: existing.titre);
      _periodStart = StudySchedule.dateOnly(existing.periodStart);
      _periodEnd = StudySchedule.dateOnly(existing.periodEnd);
      _occupancy = existing.occupancy;
      for (final subject in existing.subjects) {
        _selected[subject.matiereId] = subject;
        if (subject.projetId != null) {
          _selectedProjectIds.add(subject.projetId!);
        }
      }
    } else {
      _titreCtrl = TextEditingController(text: 'Mon emploi du temps');
      final today = StudySchedule.dateOnly(DateTime.now());
      _periodStart = today;
      _periodEnd = today.add(const Duration(days: 13));
      _occupancy = WeekOccupancy.defaults();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjetsProvider>().loadProjets();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titreCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _titreCtrl.text.trim().isEmpty) {
      _snack('Donnez un titre à votre emploi du temps.');
      return;
    }
    if (_step == 1 && _selected.isEmpty) {
      _snack('Sélectionnez au moins une matière ou un projet.');
      return;
    }
    if (_step == 2 && !_validatePeriod()) return;
    if (_step < 3) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _generate();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validatePeriod() {
    final start = StudySchedule.dateOnly(_periodStart);
    final end = StudySchedule.dateOnly(_periodEnd);
    if (end.isBefore(start)) {
      _snack('La date de fin doit être après la date de début.');
      return false;
    }
    if (StudySchedule.dayCount(start, end) < 2) {
      _snack('La période doit couvrir au moins 2 jours.');
      return false;
    }
    return true;
  }

  Future<void> _pickPeriodDate({required bool isStart}) async {
    final initial = isStart ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart ? 'Date de début' : 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _periodStart = StudySchedule.dateOnly(picked);
        if (!StudySchedule.dateOnly(_periodEnd).isAfter(_periodStart)) {
          _periodEnd = _periodStart.add(const Duration(days: 7));
        }
      } else {
        _periodEnd = StudySchedule.dateOnly(picked);
      }
    });
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      if (!_isEditing || _regenerateTasks) {
        if (Platform.isAndroid) {
          final exactOk =
              await ScheduleNotificationService.ensureExactAlarmsPermission();
          if (!exactOk && mounted) {
            _snack(
              'Autorisez « Alarmes et rappels » pour Ngenou dans les réglages. '
              'Le planning sera créé avec des rappels approximatifs.',
            );
          }
        }
      }

      if (_isEditing) {
        await context.read<ScheduleProvider>().updateSchedule(
          scheduleId: widget.scheduleToEdit!.id,
          titre: _titreCtrl.text.trim(),
          subjects: _selected.values.toList(),
          occupancy: _occupancy,
          periodStart: _periodStart,
          periodEnd: _periodEnd,
          regenerateTasks: _regenerateTasks,
        );
      } else {
        await context.read<ScheduleProvider>().createSchedule(
          titre: _titreCtrl.text.trim(),
          subjects: _selected.values.toList(),
          occupancy: _occupancy,
          periodStart: _periodStart,
          periodEnd: _periodEnd,
        );
      }
      if (mounted) {
        final provider = context.read<ScheduleProvider>();
        final aiError = provider.lastAiError;
        Navigator.pop(context, true);
        if (aiError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Emploi du temps créé avec un planning de base. L\'IA était indisponible — vérifiez votre connexion.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? (_regenerateTasks
                          ? 'Emploi du temps modifié et tâches regénérées.'
                          : 'Emploi du temps modifié.')
                    : (ScheduleNotificationService.exactAlarmsGranted
                          ? 'Emploi du temps créé avec succès !'
                          : 'Emploi du temps créé. Activez « Alarmes et rappels » pour des rappels précis.'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('exact_alarms_not_permitted')
            ? 'Autorisez les alarmes exactes : Paramètres → Applications → Ngenou → Alarmes et rappels.'
            : formatUserError(e);
        _snack(msg);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Titre',
      'Matières',
      'Occupation & période',
      'Génération IA',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_isEditing ? 'Modifier' : 'Nouveau'} planning — ${titles[_step]}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / 4, minHeight: 4),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _stepTitre(isDark),
                _stepSubjects(isDark),
                _stepRoutine(isDark),
                _stepGenerate(isDark),
              ],
            ),
          ),
          if (!_generating)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(onPressed: _back, child: const Text('Retour')),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _step == 3
                          ? (_isEditing
                                ? Icons.save_rounded
                                : Icons.auto_awesome)
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _step == 3
                          ? (_isEditing ? 'Enregistrer' : 'Générer')
                          : 'Suivant',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepTitre(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Nommez votre emploi du temps',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous pourrez le réutiliser et le régénérer autant de fois que vous voulez.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _titreCtrl,
          decoration: const InputDecoration(
            labelText: 'Titre *',
            hintText: 'Ex : Révisions Bac 2026',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _stepSubjects(bool isDark) {
    final projets = context
        .watch<ProjetsProvider>()
        .projets
        .where((p) => !p.isSystem)
        .toList();
    final matieres = ModulesRegistry.matieres;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Que voulez-vous réviser ?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sélectionnez librement les matières et/ou les projets à inclure (facultatif pour les projets).',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        if (projets.isNotEmpty) ...[
          Text(
            'Projets',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cochez un projet pour inclure ses cours — rien n\'est ajouté sans votre accord.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          ...projets.map((p) => _buildProjectCard(p, isDark)),
          const SizedBox(height: 16),
        ],
        Text(
          'Matières',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...matieres.map((m) {
          final selected = _selected.containsKey(m.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: selected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                : null,
            child: CheckboxListTile(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected[m.id] = ScheduleSubject(
                      matiereId: m.id,
                      nom: m.nom,
                      durationMinutes: m.durationMinutes,
                    );
                  } else {
                    _selected.remove(m.id);
                    for (final p in projets) {
                      if (p.matiereIds.contains(m.id) &&
                          !p.matiereIds.every(
                            (id) => _selected.containsKey(id),
                          )) {
                        _selectedProjectIds.remove(p.id);
                      }
                    }
                  }
                });
              },
              title: Text(
                m.nom,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: selected
                  ? Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DurationUtils.format(m.durationMinutes),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : null,
              secondary: Icon(m.icone),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProjectCard(Projet p, bool isDark) {
    final projectSelected = _selectedProjectIds.contains(p.id);
    // Calcule la durée totale du projet
    final totalMinutes = p.matiereIds.fold<int>(
      0,
      (sum, id) => sum + (ModulesRegistry.getMatiere(id)?.durationMinutes ?? 0),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: projectSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.06)
          : null,
      child: Column(
        children: [
          CheckboxListTile(
            value: projectSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedProjectIds.add(p.id);
                  for (final id in p.matiereIds) {
                    final m = ModulesRegistry.getMatiere(id);
                    _selected[id] = ScheduleSubject(
                      matiereId: id,
                      nom: m?.nom ?? '?',
                      durationMinutes: m?.durationMinutes ?? 0,
                      projetId: p.id,
                    );
                  }
                } else {
                  _selectedProjectIds.remove(p.id);
                  for (final id in p.matiereIds) {
                    if (_selected[id]?.projetId == p.id) {
                      _selected.remove(id);
                    }
                  }
                }
              });
            },
            title: Text(
              p.nom,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Text('${p.matiereIds.length} cours'),
                if (totalMinutes > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    DurationUtils.format(totalMinutes),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            secondary: const Icon(Icons.folder_special_rounded),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (projectSelected ||
              p.matiereIds.any((id) => _selected.containsKey(id)))
            ...p.matiereIds.map((id) {
              final m = ModulesRegistry.getMatiere(id);
              final courseSelected = _selected.containsKey(id);
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: courseSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedProjectIds.add(p.id);
                        _selected[id] = ScheduleSubject(
                          matiereId: id,
                          nom: m?.nom ?? '?',
                          durationMinutes: m?.durationMinutes ?? 0,
                          projetId: p.id,
                        );
                      } else {
                        _selected.remove(id);
                        if (!p.matiereIds.any(
                          (mid) => _selected.containsKey(mid),
                        )) {
                          _selectedProjectIds.remove(p.id);
                        }
                      }
                    });
                  },
                  title: Text(
                    m?.nom ?? '?',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: courseSelected
                      ? Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DurationUtils.format(m?.durationMinutes ?? 0),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : null,
                  secondary: Icon(m?.icone ?? Icons.help_outline, size: 20),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _stepRoutine(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Occupation & période',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Indiquez quand vous êtes occupé. L\'IA construira le reste : sommeil, révisions, pauses et moments de détente.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        Text(
          'Période du planning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _periodRangeLabel,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _periodDateTile(
                label: 'Date de début',
                date: _periodStart,
                onTap: () => _pickPeriodDate(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _periodDateTile(
                label: 'Date de fin',
                date: _periodEnd,
                onTap: () => _pickPeriodDate(isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Sommeil visé',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'L\'IA planifiera vos nuits autour de cette durée pour favoriser la mémorisation.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        Slider(
          value: _occupancy.targetSleepHours.toDouble(),
          min: 6,
          max: 10,
          divisions: 4,
          label: '${_occupancy.targetSleepHours}h',
          onChanged: (v) => setState(() {
            _occupancy = WeekOccupancy(
              weekdays: _occupancy.weekdays,
              saturday: _occupancy.saturday,
              sunday: _occupancy.sunday,
              targetSleepHours: v.round(),
            );
          }),
        ),
        Center(
          child: Text(
            '${_occupancy.targetSleepHours} heures / nuit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Heures où vous êtes occupé',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _occupancySection('Lundi → Vendredi', _occupancy.weekdays, (day) {
          setState(
            () => _occupancy = WeekOccupancy(
              weekdays: day,
              saturday: _occupancy.saturday,
              sunday: _occupancy.sunday,
              targetSleepHours: _occupancy.targetSleepHours,
            ),
          );
        }),
        const SizedBox(height: 16),
        _occupancySection('Samedi', _occupancy.saturday, (day) {
          setState(
            () => _occupancy = WeekOccupancy(
              weekdays: _occupancy.weekdays,
              saturday: day,
              sunday: _occupancy.sunday,
              targetSleepHours: _occupancy.targetSleepHours,
            ),
          );
        }),
        const SizedBox(height: 16),
        _occupancySection('Dimanche', _occupancy.sunday, (day) {
          setState(
            () => _occupancy = WeekOccupancy(
              weekdays: _occupancy.weekdays,
              saturday: _occupancy.saturday,
              sunday: day,
              targetSleepHours: _occupancy.targetSleepHours,
            ),
          );
        }),
      ],
    );
  }

  Widget _periodDateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      StudySchedule.formatDate(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _occupancySection(
    String label,
    DayOccupancy day,
    ValueChanged<DayOccupancy> onChanged,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (day.busyBlocks.isEmpty)
              Text(
                'Aucun créneau — journée libre',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              )
            else
              ...day.busyBlocks.asMap().entries.map((entry) {
                final i = entry.key;
                final block = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: block.label,
                                decoration: const InputDecoration(
                                  labelText: 'Activité',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (v) {
                                  final blocks = List<BusyBlock>.from(
                                    day.busyBlocks,
                                  );
                                  blocks[i] = block.copyWith(label: v);
                                  onChanged(day.copyWith(busyBlocks: blocks));
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                final blocks = List<BusyBlock>.from(
                                  day.busyBlocks,
                                )..removeAt(i);
                                onChanged(day.copyWith(busyBlocks: blocks));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 500) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _timePickerButton(
                                      'Début',
                                      block.startTime,
                                      (t) {
                                        final blocks = List<BusyBlock>.from(
                                          day.busyBlocks,
                                        );
                                        blocks[i] = block.copyWith(
                                          startTime: t,
                                        );
                                        onChanged(
                                          day.copyWith(busyBlocks: blocks),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _timePickerButton(
                                      'Fin',
                                      block.endTime,
                                      (t) {
                                        final blocks = List<BusyBlock>.from(
                                          day.busyBlocks,
                                        );
                                        blocks[i] = block.copyWith(endTime: t);
                                        onChanged(
                                          day.copyWith(busyBlocks: blocks),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  _timePickerButton('Début', block.startTime, (
                                    t,
                                  ) {
                                    final blocks = List<BusyBlock>.from(
                                      day.busyBlocks,
                                    );
                                    blocks[i] = block.copyWith(startTime: t);
                                    onChanged(day.copyWith(busyBlocks: blocks));
                                  }),
                                  const SizedBox(height: 12),
                                  _timePickerButton('Fin', block.endTime, (t) {
                                    final blocks = List<BusyBlock>.from(
                                      day.busyBlocks,
                                    );
                                    blocks[i] = block.copyWith(endTime: t);
                                    onChanged(day.copyWith(busyBlocks: blocks));
                                  }),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            TextButton.icon(
              onPressed: () {
                final blocks = List<BusyBlock>.from(day.busyBlocks)
                  ..add(
                    const BusyBlock(
                      startTime: '08:00',
                      endTime: '12:00',
                      label: 'Occupé',
                    ),
                  );
                onChanged(day.copyWith(busyBlocks: blocks));
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un créneau occupé'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerButton(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initialHour = int.tryParse(parts[0]) ?? 8;
        final initialMinute = int.tryParse(parts[1]) ?? 0;

        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
          helpText: label,
          cancelText: 'Annuler',
          confirmText: 'OK',
        );

        if (picked != null) {
          final newTime =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onChanged(newTime);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _stepGenerate(bool isDark) {
    if (_generating) {
      return _WizardGenerationLoader(
        periodLabel: _periodRangeLabel,
        isEditingWithoutRegen: _isEditing && !_regenerateTasks,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          _isEditing ? 'Confirmer les modifications' : 'Prêt à générer',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _recapRow(Icons.title, 'Titre', _titreCtrl.text),
        _recapRow(
          Icons.menu_book,
          'Matières',
          '${_selected.length} sélectionnée(s)',
        ),
        _recapRow(Icons.date_range, 'Période', _periodRangeLabel),
        _recapRow(
          Icons.event_busy,
          'Occupation',
          'Sem. ${_occupancy.weekdays.busyBlocks.length} · Sam ${_occupancy.saturday.busyBlocks.length} · Dim ${_occupancy.sunday.busyBlocks.length}',
        ),
        _recapRow(
          Icons.bedtime,
          'Sommeil',
          '${_occupancy.targetSleepHours} h / nuit',
        ),
        if (_isEditing) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Regénérer les créneaux avec l\'IA'),
            subtitle: const Text(
              'Décochez pour ne modifier que le titre, la période ou l\'occupation sans toucher aux blocs existants.',
            ),
            value: _regenerateTasks,
            onChanged: (v) => setState(() => _regenerateTasks = v),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isEditing
                  ? (_regenerateTasks
                        ? 'L\'IA va recréer les créneaux du ${StudySchedule.formatDate(_periodStart)} au ${StudySchedule.formatDate(_periodEnd)}. '
                              'Les tâches actuelles seront remplacées.'
                        : 'Seules les informations du planning seront mises à jour. Les tâches déjà planifiées seront conservées.')
                  : 'Création d\'emploi du temps complet (sommeil, révisions, pauses, détente) du ${StudySchedule.formatDate(_periodStart)} au ${StudySchedule.formatDate(_periodEnd)}. '
                        'Les alarmes ne sonneront que pour les créneaux de révision. '
                        'Vous devrez valider chaque tâche dans l\'app après révision.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _recapRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _WizardGenerationLoader extends StatefulWidget {
  final String periodLabel;
  final bool isEditingWithoutRegen;

  const _WizardGenerationLoader({
    required this.periodLabel,
    required this.isEditingWithoutRegen,
  });

  @override
  State<_WizardGenerationLoader> createState() =>
      _WizardGenerationLoaderState();
}

class _WizardGenerationLoaderState extends State<_WizardGenerationLoader> {
  int _messageIndex = 0;
  late final Timer _timer;
  late final List<String> _messages;

  @override
  void initState() {
    super.initState();
    if (widget.isEditingWithoutRegen) {
      _messages = [
        'Initialisation de la modification...',
        'Mise à jour des paramètres...',
        'Sauvegarde dans la base de données...',
        'Finalisation...',
      ];
    } else {
      _messages = [
        'Analyse des matières sélectionnées...',
        'Modélisation de vos disponibilités...',
        'Consultation de l\'IA Ngenou...',
        'Création des sessions d\'apprentissage...',
        'Optimisation de l\'agenda...',
        'Planification des rappels de cours...',
        'Finalisation de l\'emploi du temps...',
        'Presque terminé, veuillez patienter...',
      ];
    }

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 80,
                  width: 80,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    strokeWidth: 5,
                  ),
                ),
                Icon(Icons.auto_awesome, size: 32, color: primary),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              widget.isEditingWithoutRegen
                  ? 'Modification en cours'
                  : 'Génération en cours',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Période : ${widget.periodLabel}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : primary.withOpacity(0.1),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _messages[_messageIndex],
                    key: ValueKey<int>(_messageIndex),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
