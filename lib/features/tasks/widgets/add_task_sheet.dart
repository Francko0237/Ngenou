import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/study_task.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../modules/modules_registry.dart';

Future<DateTime?> showAddTaskSheet(
  BuildContext context, {
  StudyTask? existing,
  DateTime? initialDate,
}) async {
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddTaskSheet(existing: existing, initialDate: initialDate),
    ),
  );
}

class _AddTaskSheet extends StatefulWidget {
  final StudyTask? existing;
  final DateTime? initialDate;

  const _AddTaskSheet({this.existing, this.initialDate});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late DateTime _scheduledAt;
  late int _duration;
  late TaskPriority _priority;
  String? _matiereId;

  // Verrou anti-double-clic
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.displayTitle ?? '');
    _scheduledAt =
        existing?.scheduledAt ??
        widget.initialDate ??
        DateTime.now().add(const Duration(hours: 1));
    _duration = existing?.durationMinutes ?? 30;
    _priority = existing?.priority ?? TaskPriority.normal;
    _matiereId =
        existing?.matiereId != null &&
            existing!.matiereId != 'manual' &&
            existing.matiereId != StudyTask.lifeRhythmMatiereId
        ? existing.matiereId
        : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    // Validation via Form — affiche l'erreur inline sans snackbar
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Anti-double-clic
    if (_saving) return;
    setState(() => _saving = true);

    final scheduledAt = _scheduledAt;
    final title = _titleCtrl.text.trim();
    final provider = context.read<ScheduleProvider>();
    final matiere = _matiereId != null
        ? ModulesRegistry.getMatiere(_matiereId!)
        : null;

    // Fermeture optimiste : on pop AVANT l'await pour que l'UI réponde immédiatement
    if (mounted) Navigator.pop(context, scheduledAt);

    // La BDD + notification se font en arrière-plan après le pop
    if (widget.existing != null) {
      await provider.updateTaskDetails(
        taskId: widget.existing!.id,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: _duration,
        priority: _priority,
        matiereId: matiere?.id,
        matiereNom: matiere?.nom ?? _matiereId,
      );
    } else {
      await provider.addManualTask(
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: _duration,
        priority: _priority,
        matiereId: matiere?.id,
        matiereNom: matiere?.nom ?? _matiereId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matieres = ModulesRegistry.matieres;
    final primary = Theme.of(context).primaryColor;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          // Padding adaptatif : plus serré sur petits écrans
          MediaQuery.of(context).size.width < 360 ? 12 : 20,
          12,
          MediaQuery.of(context).size.width < 360 ? 12 : 20,
          20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null
                      ? 'Nouvelle tâche'
                      : 'Modifier la tâche',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                // TextFormField avec validation inline (erreur affichée sous le champ)
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.done,
                  autofocus: widget.existing == null,
                  decoration: const InputDecoration(
                    labelText: 'Titre *',
                    border: OutlineInputBorder(),
                    helperText:
                        ' ', // espace réservé pour l'erreur (évite le layout shift)
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Indiquez un titre pour la tâche';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${_scheduledAt.day.toString().padLeft(2, '0')}/${_scheduledAt.month.toString().padLeft(2, '0')}/${_scheduledAt.year}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Durée : $_duration min',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _duration.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 11,
                  label: '$_duration min',
                  onChanged: (v) => setState(() => _duration = v.round()),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Priorité',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: TaskPriority.values.map((p) {
                    final selected = _priority == p;
                    return ChoiceChip(
                      label: Text(
                        p.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _priority = p),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _matiereId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Matière (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucune')),
                    ...matieres.map(
                      (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.nom, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _matiereId = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing == null ? 'Ajouter' : 'Enregistrer',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
