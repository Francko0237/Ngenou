import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/study_task.dart';
import '../../../core/providers/defis_provider.dart';
import '../../../core/providers/schedule_provider.dart';

class QuotidienTab extends StatelessWidget {
  const QuotidienTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final scheduleProvider = context.watch<ScheduleProvider>();
    final defisProvider = context.watch<DefisProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hPad = w > 1200 ? w * 0.08 : w > 700 ? w * 0.05 : 18.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── En-tête de section ─────────────────────────────────────────
              Text(
                'Mon Quotidien 📅',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF15151C),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Organisation, tâches et discipline de révision',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // ─── 1. Le Défi du Jour (Hero Card valorisante) ──────────────────
              _buildDefiDuJourHero(context, defisProvider, isDark),
              const SizedBox(height: 20),

              // ─── 2. Tâches d'aujourd'hui ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tâches d'aujourd'hui",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF15151C),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/taches'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Tout voir', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTodayTasksSummary(context, scheduleProvider, isDark, primary),
              const SizedBox(height: 20),

              // ─── 3. Emploi du temps & Planning ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Emploi du temps & Planning',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF15151C),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/planning'),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Gérer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPlanningCard(context, scheduleProvider, isDark),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefiDuJourHero(
    BuildContext context,
    DefisProvider defisProvider,
    bool isDark,
  ) {
    final session = defisProvider.todaySession;
    final hasSession = session != null;
    final isComplete = hasSession && session.completed;
    final score = hasSession ? session.score : 0;
    final total = hasSession ? session.total : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF3498DB), const Color(0xFF1B6FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3498DB).withValues(alpha: isDark ? 0.25 : 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/defis'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isComplete ? Icons.emoji_events_rounded : Icons.local_fire_department_rounded,
                    size: 30,
                    color: isComplete ? const Color(0xFFFFD700) : Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Défi Quotidien',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? const Color(0xFF2ECC71)
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isComplete ? 'Validé 🎉' : '+20 XP',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isComplete
                            ? 'Score : $score/$total — Objectif du jour atteint !'
                            : hasSession
                                ? '$score/$total réussis · Cliquez pour terminer'
                                : '3 minutes • 5 questions rapides générées par IA',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isComplete ? 'Revoir' : 'Lancer ▶',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1B6FA8),
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

  Widget _buildTodayTasksSummary(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    bool isDark,
    Color primary,
  ) {
    final tasks = scheduleProvider.upcomingTasks;
    final count = scheduleProvider.todayStudyTaskCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_rounded, size: 20, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count > 0 ? '$count tâche${count > 1 ? 's' : ''} programmée${count > 1 ? 's' : ''}' : 'Aucune tâche urgente',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF15151C),
                      ),
                    ),
                    Text(
                      count > 0 ? 'Gardez le cap pour votre révision' : 'Planifiez votre travail dès maintenant',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/taches', extra: 'add'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.take(3).length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final task = tasks[i];
                final isCompleted = task.status == TaskStatus.completed;
                return InkWell(
                  onTap: () => context.push('/taches'),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: isCompleted ? const Color(0xFF2ECC71) : (isDark ? Colors.white38 : Colors.black38),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            task.displayTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanningCard(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    bool isDark,
  ) {
    final schedulesCount = scheduleProvider.schedules.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/planning'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 24, color: Color(0xFF8E24AA)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedulesCount > 0
                            ? '$schedulesCount créneau${schedulesCount > 1 ? 'x' : ''} configuré${schedulesCount > 1 ? 's' : ''}'
                            : 'Générer un emploi du temps IA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF15151C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rappels automatiques et calendrier hebdomadaire',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
