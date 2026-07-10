import 'package:flutter/material.dart';
import '../../../core/models/study_task.dart';
import '../../../core/models/task_priority.dart';
import '../task_format.dart';

class TaskCard extends StatelessWidget {
  final StudyTask task;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onChecked;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onChecked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = task.status == TaskStatus.completed;
    final isCancelled = task.status == TaskStatus.cancelled;
    final accent = task.isLate && task.isPending
        ? Colors.red
        : taskAccentColor(task.matiereId, context);
    final bg = isDone || isCancelled
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50)
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius:
                        const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      if (onChecked != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: isDone,
                              onChanged: isDone || isCancelled ? null : onChecked,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      if (onChecked != null) const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.displayTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                decoration: isDone || isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone || isCancelled
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule_rounded,
                                        size: 15, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      TaskFormat.time(task.scheduledAt),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                _PriorityBadge(priority: task.priority),
                                if (task.isLate && task.isPending)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Retard',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (isDone)
                                  const _StatusChip(
                                    label: 'Effectuée',
                                    color: Colors.green,
                                  ),
                                if (isCancelled)
                                  const _StatusChip(
                                    label: 'Annulée',
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

class _PriorityBadge extends StatelessWidget {
  final TaskPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final isUrgent = priority == TaskPriority.urgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.pink.shade50
            : Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? Colors.pink.shade200
              : Theme.of(context).primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.circle,
            size: isUrgent ? 14 : 8,
            color: isUrgent ? Colors.red : Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isUrgent ? Colors.red : Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
