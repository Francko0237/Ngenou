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
    backgroundColor: Colors.transparent,
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;
    setState(() => _saving = true);

    final scheduledAt = _scheduledAt;
    final title = _titleCtrl.text.trim();
    final provider = context.read<ScheduleProvider>();
    final matiere = _matiereId != null
        ? ModulesRegistry.getMatiere(_matiereId!)
        : null;

    if (mounted) Navigator.pop(context, scheduledAt);

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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final matieres = ModulesRegistry.matieres;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final isNew = widget.existing == null;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW < 360 ? 12.0 : 20.0;

    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final sectionBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.025);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ──
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Titre du sheet ──
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isNew
                              ? Icons.add_task_rounded
                              : Icons.edit_note_rounded,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isNew ? 'Nouvelle tâche' : 'Modifier la tâche',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Section : Titre ──
                  TextFormField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.done,
                    autofocus: isNew,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex : Réviser le chapitre 3',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.drive_file_rename_outline_rounded,
                        color: primary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: sectionBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      errorStyle:
                          const TextStyle(height: 1.2, fontSize: 11),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Indiquez un titre pour la tâche';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Section : Date & heure ──
                  _SectionLabel(label: 'QUAND', isDark: isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerButton(
                          icon: Icons.calendar_today_rounded,
                          label: _formatDate(_scheduledAt),
                          isDark: isDark,
                          primary: primary,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerButton(
                          icon: Icons.access_time_rounded,
                          label: _formatTime(_scheduledAt),
                          isDark: isDark,
                          primary: primary,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section : Durée ──
                  _SectionLabel(label: 'DURÉE', isDark: isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    decoration: BoxDecoration(
                      color: sectionBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timelapse_rounded,
                                    size: 16, color: primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Durée estimée',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_duration min',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _duration.toDouble(),
                          min: 15,
                          max: 180,
                          divisions: 11,
                          activeColor: primary,
                          inactiveColor: primary.withValues(alpha: 0.15),
                          label: '$_duration min',
                          onChanged: (v) =>
                              setState(() => _duration = v.round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Section : Priorité ──
                  _SectionLabel(label: 'PRIORITÉ', isDark: isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: TaskPriority.values.map((p) {
                      final selected = _priority == p;
                      final isUrgent = p == TaskPriority.urgent;
                      final chipColor =
                          isUrgent ? Colors.red : Colors.green;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: p != TaskPriority.values.last ? 10 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? chipColor.withValues(alpha: 0.12)
                                    : sectionBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? chipColor.withValues(alpha: 0.5)
                                      : borderColor,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isUrgent
                                        ? Icons.priority_high_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: selected
                                        ? chipColor
                                        : (isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? chipColor
                                          : (isDark
                                              ? Colors.white54
                                              : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Section : Matière ──
                  _SectionLabel(label: 'MATIÈRE (optionnel)', isDark: isDark),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: sectionBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _matiereId,
                      isExpanded: true,
                      dropdownColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
                      icon: Icon(Icons.expand_more_rounded,
                          color: isDark ? Colors.white38 : Colors.black38),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.menu_book_outlined,
                            color: primary, size: 20),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                      hint: Text(
                        'Aucune matière',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Aucune')),
                        ...matieres.map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.nom,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _matiereId = v),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Bouton de sauvegarde ──
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          primary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isNew ? Icons.add_rounded : Icons.save_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isNew ? 'Ajouter la tâche' : 'Enregistrer',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────


class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
