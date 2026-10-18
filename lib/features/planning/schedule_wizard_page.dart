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

// ── Constantes visuelles ──────────────────────────────────────────────────────

const _kCardRadius = 16.0;

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

  static const _stepLabels = ['Titre', 'Matières', 'Agenda', 'Récap'];

  @override
  void initState() {
    super.initState();
    final e = widget.scheduleToEdit;
    if (e != null) {
      _titreCtrl = TextEditingController(text: e.titre);
      _periodStart = StudySchedule.dateOnly(e.periodStart);
      _periodEnd = StudySchedule.dateOnly(e.periodEnd);
      _occupancy = e.occupancy;
      for (final s in e.subjects) {
        _selected[s.matiereId] = s;
        if (s.projetId != null) _selectedProjectIds.add(s.projetId!);
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

  // ── Navigation ──────────────────────────────────────────────────────────────

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
        duration: const Duration(milliseconds: 350),
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
      duration: const Duration(milliseconds: 350),
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
      confirmText: 'Choisir',
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      if (!_isEditing || _regenerateTasks) {
        if (Platform.isAndroid) {
          final ok = await ScheduleNotificationService.ensureExactAlarmsPermission();
          if (!ok && mounted) {
            _snack(
              'Autorisez « Alarmes et rappels » dans les réglages. '
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
        final aiError = context.read<ScheduleProvider>().lastAiError;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiError != null
                  ? 'Planning créé avec un agenda de base. L\'IA était indisponible.'
                  : _isEditing
                      ? (_regenerateTasks
                          ? 'Planning modifié et recréé par l\'IA.'
                          : 'Planning modifié.')
                      : 'Emploi du temps créé avec succès !',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _snack(e.toString().contains('exact_alarms_not_permitted')
            ? 'Autorisez les alarmes : Paramètres → Applications → Ngenou → Alarmes et rappels.'
            : formatUserError(e));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Build principal ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: _step,
              isEditing: _isEditing,
              labels: _stepLabels,
              primary: primary,
              isDark: isDark,
              onBack: _back,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepTitre(
                    ctrl: _titreCtrl,
                    isDark: isDark,
                    primary: primary,
                  ),
                  _StepSubjects(
                    selected: _selected,
                    selectedProjectIds: _selectedProjectIds,
                    isDark: isDark,
                    primary: primary,
                    onChanged: (selected, projectIds) => setState(() {
                      _selected
                        ..clear()
                        ..addAll(selected);
                      _selectedProjectIds
                        ..clear()
                        ..addAll(projectIds);
                    }),
                  ),
                  _StepRoutine(
                    occupancy: _occupancy,
                    periodStart: _periodStart,
                    periodEnd: _periodEnd,
                    isDark: isDark,
                    primary: primary,
                    onOccupancyChanged: (o) => setState(() => _occupancy = o),
                    onPickDate: _pickPeriodDate,
                  ),
                  _generating
                      ? _WizardGenerationLoader(
                          periodLabel: _periodRangeLabel,
                          isEditingWithoutRegen: _isEditing && !_regenerateTasks,
                        )
                      : _StepRecap(
                          titre: _titreCtrl.text,
                          selectedCount: _selected.length,
                          periodLabel: _periodRangeLabel,
                          occupancy: _occupancy,
                          periodStart: _periodStart,
                          periodEnd: _periodEnd,
                          isEditing: _isEditing,
                          regenerateTasks: _regenerateTasks,
                          isDark: isDark,
                          primary: primary,
                          onRegenerateChanged: (v) =>
                              setState(() => _regenerateTasks = v),
                        ),
                ],
              ),
            ),
            if (!_generating)
              _WizardFooter(
                step: _step,
                isEditing: _isEditing,
                primary: primary,
                isDark: isDark,
                onBack: _back,
                onNext: _next,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header avec stepper ───────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step;
  final bool isEditing;
  final List<String> labels;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack;

  const _WizardHeader({
    required this.step,
    required this.isEditing,
    required this.labels,
    required this.primary,
    required this.isDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Ligne titre + back
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Modifier le planning' : 'Nouveau planning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Text(
                '${step + 1}/${labels.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stepper
          Row(
            children: List.generate(labels.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Ligne de connexion
                final lineStep = i ~/ 2;
                final done = lineStep < step;
                return Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: done
                          ? primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final idx = i ~/ 2;
              final active = idx == step;
              final done = idx < step;
              return _StepDot(
                index: idx,
                label: labels[idx],
                active: active,
                done: done,
                primary: primary,
                isDark: isDark,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;
  final Color primary;
  final bool isDark;

  const _StepDot({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 32 : 28,
          height: active ? 32 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active
                ? primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
            border: Border.all(
              color: active ? primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: active
                ? [BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 8)]
                : [],
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active || done
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? primary
                : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ],
    );
  }
}

// ── Footer navigation ─────────────────────────────────────────────────────────

class _WizardFooter extends StatelessWidget {
  final int step;
  final bool isEditing;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _WizardFooter({
    required this.step,
    required this.isEditing,
    required this.primary,
    required this.isDark,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(
                isLast
                    ? (isEditing
                        ? Icons.save_rounded
                        : Icons.auto_awesome_rounded)
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                isLast
                    ? (isEditing ? 'Enregistrer' : 'Générer')
                    : 'Suivant',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Étape 1 : Titre ───────────────────────────────────────────────────────────

class _StepTitre extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final Color primary;

  const _StepTitre({
    required this.ctrl,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          icon: Icons.edit_note_rounded,
          title: 'Nommez votre planning',
          subtitle:
              'Vous pourrez le régénérer autant de fois que vous voulez avec l\'IA.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _SectionCard(
          isDark: isDark,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            decoration: InputDecoration(
              hintText: 'Ex : Révisions Bac 2026',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(Icons.title_rounded, color: primary, size: 22),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'Un bon titre vous aidera à retrouver et distinguer vos plannings facilement.',
          isDark: isDark,
          primary: primary,
        ),
      ],
    );
  }
}

// ── Étape 2 : Matières ────────────────────────────────────────────────────────

class _StepSubjects extends StatelessWidget {
  final Map<String, ScheduleSubject> selected;
  final Set<String> selectedProjectIds;
  final bool isDark;
  final Color primary;
  final void Function(Map<String, ScheduleSubject>, Set<String>) onChanged;

  const _StepSubjects({
    required this.selected,
    required this.selectedProjectIds,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final projets = context
        .watch<ProjetsProvider>()
        .projets
        .where((p) => !p.isSystem)
        .toList();
    final matieres = ModulesRegistry.matieres;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          icon: Icons.menu_book_rounded,
          title: 'Que réviser ?',
          subtitle:
              'Sélectionnez les matières et/ou projets à inclure dans votre planning.',
          primary: primary,
          isDark: isDark,
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SelectedBadge(count: selected.length, primary: primary, isDark: isDark),
        ],
        if (projets.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: 'Projets', isDark: isDark),
          const SizedBox(height: 8),
          ...projets.map((p) => _ProjectTile(
                projet: p,
                selected: selected,
                selectedProjectIds: selectedProjectIds,
                isDark: isDark,
                primary: primary,
                onChanged: onChanged,
              )),
        ],
        const SizedBox(height: 20),
        _SectionLabel(label: 'Matières', isDark: isDark),
        const SizedBox(height: 8),
        ...matieres.map((m) {
          final isSelected = selected.containsKey(m.id);
          return _MatiereTile(
            matiereId: m.id,
            nom: m.nom,
            icone: m.icone,
            durationMinutes: m.durationMinutes,
            isSelected: isSelected,
            isDark: isDark,
            primary: primary,
            onToggle: (v) {
              final newSelected = Map<String, ScheduleSubject>.from(selected);
              final newProjectIds = Set<String>.from(selectedProjectIds);
              if (v) {
                newSelected[m.id] = ScheduleSubject(
                  matiereId: m.id,
                  nom: m.nom,
                  durationMinutes: m.durationMinutes,
                );
              } else {
                newSelected.remove(m.id);
                for (final p in projets) {
                  if (p.matiereIds.contains(m.id) &&
                      !p.matiereIds.every((id) => newSelected.containsKey(id))) {
                    newProjectIds.remove(p.id);
                  }
                }
              }
              onChanged(newSelected, newProjectIds);
            },
          );
        }),
      ],
    );
  }
}

class _MatiereTile extends StatelessWidget {
  final String matiereId;
  final String nom;
  final IconData icone;
  final int durationMinutes;
  final bool isSelected;
  final bool isDark;
  final Color primary;
  final ValueChanged<bool> onToggle;

  const _MatiereTile({
    required this.matiereId,
    required this.nom,
    required this.icone,
    required this.durationMinutes,
    required this.isSelected,
    required this.isDark,
    required this.primary,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.15 : 0.07)
              : (isDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white),
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icone,
                size: 20,
                color: isSelected
                    ? primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (isSelected)
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 11, color: primary),
                        const SizedBox(width: 3),
                        Text(
                          DurationUtils.format(durationMinutes),
                          style: TextStyle(
                            fontSize: 11,
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.white24 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Projet projet;
  final Map<String, ScheduleSubject> selected;
  final Set<String> selectedProjectIds;
  final bool isDark;
  final Color primary;
  final void Function(Map<String, ScheduleSubject>, Set<String>) onChanged;

  const _ProjectTile({
    required this.projet,
    required this.selected,
    required this.selectedProjectIds,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = projet;
    final projectSelected = selectedProjectIds.contains(p.id);
    final totalMinutes = p.matiereIds.fold<int>(
      0,
      (sum, id) => sum + (ModulesRegistry.getMatiere(id)?.durationMinutes ?? 0),
    );
    final showChildren =
        projectSelected || p.matiereIds.any((id) => selected.containsKey(id));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: projectSelected
            ? primary.withValues(alpha: isDark ? 0.12 : 0.06)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: projectSelected
              ? primary.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06)),
          width: projectSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              final newSelected = Map<String, ScheduleSubject>.from(selected);
              final newProjectIds = Set<String>.from(selectedProjectIds);
              if (!projectSelected) {
                newProjectIds.add(p.id);
                for (final id in p.matiereIds) {
                  final m = ModulesRegistry.getMatiere(id);
                  newSelected[id] = ScheduleSubject(
                    matiereId: id,
                    nom: m?.nom ?? '?',
                    durationMinutes: m?.durationMinutes ?? 0,
                    projetId: p.id,
                  );
                }
              } else {
                newProjectIds.remove(p.id);
                for (final id in p.matiereIds) {
                  if (newSelected[id]?.projetId == p.id) {
                    newSelected.remove(id);
                  }
                }
              }
              onChanged(newSelected, newProjectIds);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: projectSelected
                          ? primary.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_special_rounded,
                      size: 20,
                      color: projectSelected
                          ? primary
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nom,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${p.matiereIds.length} cours',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            if (totalMinutes > 0) ...[
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                              Icon(Icons.schedule_rounded,
                                  size: 11, color: primary),
                              const SizedBox(width: 3),
                              Text(
                                DurationUtils.format(totalMinutes),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: projectSelected ? primary : Colors.transparent,
                      border: Border.all(
                        color: projectSelected
                            ? primary
                            : (isDark ? Colors.white24 : Colors.black26),
                        width: 1.5,
                      ),
                    ),
                    child: projectSelected
                        ? const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (showChildren)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: Column(
                children: p.matiereIds.map((id) {
                  final m = ModulesRegistry.getMatiere(id);
                  final courseSelected = selected.containsKey(id);
                  return GestureDetector(
                    onTap: () {
                      final newSelected =
                          Map<String, ScheduleSubject>.from(selected);
                      final newProjectIds =
                          Set<String>.from(selectedProjectIds);
                      if (!courseSelected) {
                        newProjectIds.add(p.id);
                        newSelected[id] = ScheduleSubject(
                          matiereId: id,
                          nom: m?.nom ?? '?',
                          durationMinutes: m?.durationMinutes ?? 0,
                          projetId: p.id,
                        );
                      } else {
                        newSelected.remove(id);
                        if (!p.matiereIds
                            .any((mid) => newSelected.containsKey(mid))) {
                          newProjectIds.remove(p.id);
                        }
                      }
                      onChanged(newSelected, newProjectIds);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: courseSelected
                                  ? primary.withValues(alpha: 0.12)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              m?.icone ?? Icons.help_outline,
                              size: 14,
                              color: courseSelected
                                  ? primary
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m?.nom ?? '?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: courseSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  courseSelected ? primary : Colors.transparent,
                              border: Border.all(
                                color: courseSelected
                                    ? primary
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.black26),
                                width: 1.5,
                              ),
                            ),
                            child: courseSelected
                                ? const Icon(Icons.check_rounded,
                                    size: 11, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Étape 3 : Routine & période ───────────────────────────────────────────────

class _StepRoutine extends StatelessWidget {
  final WeekOccupancy occupancy;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool isDark;
  final Color primary;
  final ValueChanged<WeekOccupancy> onOccupancyChanged;
  final Future<void> Function({required bool isStart}) onPickDate;

  const _StepRoutine({
    required this.occupancy,
    required this.periodStart,
    required this.periodEnd,
    required this.isDark,
    required this.primary,
    required this.onOccupancyChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          icon: Icons.event_available_rounded,
          title: 'Agenda & disponibilités',
          subtitle:
              'Indiquez la période et vos créneaux occupés. L\'IA gère le reste.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        // Période
        _SectionLabel(label: 'Période du planning', isDark: isDark),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DatePickerTile(
                label: 'Début',
                date: periodStart,
                isDark: isDark,
                primary: primary,
                onTap: () => onPickDate(isStart: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            Expanded(
              child: _DatePickerTile(
                label: 'Fin',
                date: periodEnd,
                isDark: isDark,
                primary: primary,
                onTap: () => onPickDate(isStart: false),
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: primary),
              const SizedBox(width: 8),
              Text(
                StudySchedule.dateRangeLabel(periodStart, periodEnd),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Sommeil
        _SectionLabel(label: 'Durée de sommeil visée', isDark: isDark),
        const SizedBox(height: 8),
        _SectionCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bedtime_rounded, size: 18, color: primary),
                      const SizedBox(width: 8),
                      Text(
                        'Sommeil / nuit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${occupancy.targetSleepHours}h',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: occupancy.targetSleepHours.toDouble(),
                min: 6,
                max: 10,
                divisions: 4,
                activeColor: primary,
                inactiveColor: primary.withValues(alpha: 0.15),
                label: '${occupancy.targetSleepHours}h',
                onChanged: (v) => onOccupancyChanged(WeekOccupancy(
                  weekdays: occupancy.weekdays,
                  saturday: occupancy.saturday,
                  sunday: occupancy.sunday,
                  targetSleepHours: v.round(),
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Créneaux occupés
        _SectionLabel(label: 'Créneaux occupés', isDark: isDark),
        const SizedBox(height: 4),
        Text(
          'L\'IA planifiera vos révisions en dehors de ces plages.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 12),
        _OccupancySection(
          label: 'Lun → Ven',
          icon: Icons.work_outline_rounded,
          day: occupancy.weekdays,
          isDark: isDark,
          primary: primary,
          onChanged: (d) => onOccupancyChanged(WeekOccupancy(
            weekdays: d,
            saturday: occupancy.saturday,
            sunday: occupancy.sunday,
            targetSleepHours: occupancy.targetSleepHours,
          )),
        ),
        const SizedBox(height: 10),
        _OccupancySection(
          label: 'Samedi',
          icon: Icons.weekend_outlined,
          day: occupancy.saturday,
          isDark: isDark,
          primary: primary,
          onChanged: (d) => onOccupancyChanged(WeekOccupancy(
            weekdays: occupancy.weekdays,
            saturday: d,
            sunday: occupancy.sunday,
            targetSleepHours: occupancy.targetSleepHours,
          )),
        ),
        const SizedBox(height: 10),
        _OccupancySection(
          label: 'Dimanche',
          icon: Icons.self_improvement_rounded,
          day: occupancy.sunday,
          isDark: isDark,
          primary: primary,
          onChanged: (d) => onOccupancyChanged(WeekOccupancy(
            weekdays: occupancy.weekdays,
            saturday: occupancy.saturday,
            sunday: d,
            targetSleepHours: occupancy.targetSleepHours,
          )),
        ),
      ],
    );
  }
}

class _OccupancySection extends StatelessWidget {
  final String label;
  final IconData icon;
  final DayOccupancy day;
  final bool isDark;
  final Color primary;
  final ValueChanged<DayOccupancy> onChanged;

  const _OccupancySection({
    required this.label,
    required this.icon,
    required this.day,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              if (day.busyBlocks.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Libre',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green),
                  ),
                ),
            ],
          ),
          if (day.busyBlocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...day.busyBlocks.asMap().entries.map((entry) {
              final i = entry.key;
              final block = entry.value;
              return _BusyBlockRow(
                block: block,
                isDark: isDark,
                primary: primary,
                onDelete: () {
                  final blocks = List<BusyBlock>.from(day.busyBlocks)
                    ..removeAt(i);
                  onChanged(day.copyWith(busyBlocks: blocks));
                },
                onLabelChanged: (v) {
                  final blocks = List<BusyBlock>.from(day.busyBlocks);
                  blocks[i] = block.copyWith(label: v);
                  onChanged(day.copyWith(busyBlocks: blocks));
                },
                onStartChanged: (t) {
                  final blocks = List<BusyBlock>.from(day.busyBlocks);
                  blocks[i] = block.copyWith(startTime: t);
                  onChanged(day.copyWith(busyBlocks: blocks));
                },
                onEndChanged: (t) {
                  final blocks = List<BusyBlock>.from(day.busyBlocks);
                  blocks[i] = block.copyWith(endTime: t);
                  onChanged(day.copyWith(busyBlocks: blocks));
                },
              );
            }),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final blocks = List<BusyBlock>.from(day.busyBlocks)
                ..add(const BusyBlock(
                    startTime: '08:00', endTime: '12:00', label: 'Occupé'));
              onChanged(day.copyWith(busyBlocks: blocks));
            },
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 16, color: primary),
                const SizedBox(width: 6),
                Text(
                  'Ajouter un créneau',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyBlockRow extends StatelessWidget {
  final BusyBlock block;
  final bool isDark;
  final Color primary;
  final VoidCallback onDelete;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;

  const _BusyBlockRow({
    required this.block,
    required this.isDark,
    required this.primary,
    required this.onDelete,
    required this.onLabelChanged,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: block.label)
                    ..selection = TextSelection.collapsed(
                        offset: block.label.length),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Activité',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                  onChanged: onLabelChanged,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Début',
                  value: block.startTime,
                  isDark: isDark,
                  primary: primary,
                  onChanged: onStartChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.black26),
              ),
              Expanded(
                child: _TimeButton(
                  label: 'Fin',
                  value: block.endTime,
                  isDark: isDark,
                  primary: primary,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color primary;
  final ValueChanged<String> onChanged;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final parts = value.split(':');
        final h = int.tryParse(parts[0]) ?? 8;
        final m = int.tryParse(parts[1]) ?? 0;
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
          helpText: label,
          cancelText: 'Annuler',
          confirmText: 'OK',
        );
        if (picked != null) {
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: primary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 4 : Récapitulatif ───────────────────────────────────────────────────

class _StepRecap extends StatelessWidget {
  final String titre;
  final int selectedCount;
  final String periodLabel;
  final WeekOccupancy occupancy;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool isEditing;
  final bool regenerateTasks;
  final bool isDark;
  final Color primary;
  final ValueChanged<bool> onRegenerateChanged;

  const _StepRecap({
    required this.titre,
    required this.selectedCount,
    required this.periodLabel,
    required this.occupancy,
    required this.periodStart,
    required this.periodEnd,
    required this.isEditing,
    required this.regenerateTasks,
    required this.isDark,
    required this.primary,
    required this.onRegenerateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          icon: isEditing ? Icons.save_rounded : Icons.auto_awesome_rounded,
          title: isEditing ? 'Confirmer les modifications' : 'Prêt à générer',
          subtitle: isEditing
              ? 'Vérifiez les informations avant d\'enregistrer.'
              : 'L\'IA va créer votre emploi du temps complet.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _SectionCard(
          isDark: isDark,
          child: Column(
            children: [
              _RecapRow(
                  icon: Icons.title_rounded,
                  label: 'Titre',
                  value: titre,
                  isDark: isDark,
                  primary: primary),
              _Divider(isDark: isDark),
              _RecapRow(
                  icon: Icons.menu_book_rounded,
                  label: 'Matières',
                  value: '$selectedCount sélectionnée${selectedCount > 1 ? 's' : ''}',
                  isDark: isDark,
                  primary: primary),
              _Divider(isDark: isDark),
              _RecapRow(
                  icon: Icons.date_range_rounded,
                  label: 'Période',
                  value: periodLabel,
                  isDark: isDark,
                  primary: primary),
              _Divider(isDark: isDark),
              _RecapRow(
                  icon: Icons.bedtime_rounded,
                  label: 'Sommeil',
                  value: '${occupancy.targetSleepHours} h / nuit',
                  isDark: isDark,
                  primary: primary),
              _Divider(isDark: isDark),
              _RecapRow(
                  icon: Icons.event_busy_rounded,
                  label: 'Créneaux occupés',
                  value:
                      'Sem. ${occupancy.weekdays.busyBlocks.length} · Sam. ${occupancy.saturday.busyBlocks.length} · Dim. ${occupancy.sunday.busyBlocks.length}',
                  isDark: isDark,
                  primary: primary),
            ],
          ),
        ),
        if (isEditing) ...[
          const SizedBox(height: 16),
          _SectionCard(
            isDark: isDark,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Regénérer les créneaux avec l\'IA',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              subtitle: Text(
                'Décochez pour ne modifier que le titre ou la période sans refaire les blocs.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              value: regenerateTasks,
              activeColor: primary,
              onChanged: onRegenerateChanged,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _InfoBanner(
          icon: isEditing ? Icons.info_outline_rounded : Icons.auto_awesome_outlined,
          text: isEditing
              ? (regenerateTasks
                  ? 'L\'IA va recréer les créneaux du ${StudySchedule.formatDate(periodStart)} au ${StudySchedule.formatDate(periodEnd)}. Les tâches actuelles seront remplacées.'
                  : 'Seules les informations du planning seront mises à jour. Les tâches existantes seront conservées.')
              : 'L\'IA créera un planning complet (sommeil, révisions, pauses) du ${StudySchedule.formatDate(periodStart)} au ${StudySchedule.formatDate(periodEnd)}.',
          isDark: isDark,
          primary: primary,
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color primary;

  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loader de génération ──────────────────────────────────────────────────────

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
    _messages = widget.isEditingWithoutRegen
        ? [
            'Initialisation de la modification...',
            'Mise à jour des paramètres...',
            'Sauvegarde en base de données...',
            'Finalisation...',
          ]
        : [
            'Analyse des matières sélectionnées...',
            'Modélisation de vos disponibilités...',
            'Consultation de l\'IA Ngenou...',
            'Création des sessions d\'apprentissage...',
            'Optimisation de l\'agenda...',
            'Planification des rappels...',
            'Finalisation de l\'emploi du temps...',
          ];
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
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
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    strokeWidth: 4,
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, size: 28, color: primary),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              widget.isEditingWithoutRegen
                  ? 'Modification en cours'
                  : 'Génération en cours',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.periodLabel,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : primary.withValues(alpha: 0.1),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final bool isDark;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color primary;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  final int count;
  final Color primary;
  final bool isDark;

  const _SelectedBadge({
    required this.count,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 14, color: primary),
          const SizedBox(width: 6),
          Text(
            '$count matière${count > 1 ? 's' : ''} sélectionnée${count > 1 ? 's' : ''}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: primary),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: primary),
                const SizedBox(width: 6),
                Text(
                  StudySchedule.formatDate(date),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
      );
}
