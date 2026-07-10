import 'package:flutter/material.dart';
import '../../../core/models/study_task.dart';
import '../../../core/providers/schedule_provider.dart';
import 'package:provider/provider.dart';
import 'add_task_sheet.dart';

Future<bool> showTaskActionSheet(BuildContext context, StudyTask task) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _TaskActionSheet(task: task),
  );
  return result ?? false;
}

class _TaskActionSheet extends StatelessWidget {
  final StudyTask task;

  const _TaskActionSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final canEdit = task.isPending;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      task.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (canEdit)
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Modifier',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  final newDate = await showAddTaskSheet(
                    context,
                    existing: task,
                  );
                  if (newDate != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tâche mise à jour')),
                    );
                  }
                },
              ),
            if (canEdit)
              _ActionTile(
                icon: Icons.check_circle_rounded,
                label: 'Marquer comme effectuée',
                color: Colors.green,
                onTap: () async {
                  await provider.completeTask(task.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
            if (canEdit)
              _ActionTile(
                icon: Icons.cancel_outlined,
                label: 'Annuler la tâche',
                color: Colors.orange,
                onTap: () async {
                  await provider.cancelTask(task.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
            if (task.isManual || canEdit)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer',
                color: Colors.red,
                onTap: () async {
                  await provider.deleteTask(task.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
            if (!canEdit && task.status == TaskStatus.completed)
              _ActionTile(
                icon: Icons.restore_rounded,
                label: 'Remettre en attente',
                color: Colors.orange,
                onTap: () async {
                  await provider.updateTaskDetails(
                    taskId: task.id,
                    title: task.displayTitle,
                    scheduledAt: task.scheduledAt,
                    durationMinutes: task.durationMinutes,
                    priority: task.priority,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
