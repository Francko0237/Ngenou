import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/study_schedule.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/utils/error_formatter.dart';
import 'schedule_detail_page.dart';
import 'schedule_wizard_page.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, provider, isDark, primary),
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.schedules.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onCreate: () => _openWizard(context)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final s = provider.schedules[index];
                    return _ScheduleCard(
                      schedule: s,
                      primary: primary,
                      isDark: isDark,
                      onTap: () => _openScheduleDetail(context, s),
                      onEdit: () => _openEditWizard(context, s),
                      onRegenerate: () => _regenerate(context, s.id),
                      onDelete: () => _delete(context, s.id),
                    );
                  },
                  childCount: provider.schedules.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(context),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nouveau planning',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ScheduleProvider provider,
    bool isDark,
    Color primary,
  ) {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emploi du temps',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
            if (!provider.isLoading)
              Text(
                provider.schedules.isEmpty
                    ? 'Aucun planning'
                    : '${provider.schedules.length} planning${provider.schedules.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openWizard(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleWizardPage()),
    ).then((_) => context.read<ScheduleProvider>().load());
  }

  void _openEditWizard(BuildContext context, StudySchedule schedule) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleWizardPage(scheduleToEdit: schedule),
      ),
    ).then((changed) {
      if (changed == true && context.mounted) {
        context.read<ScheduleProvider>().load();
      }
    });
  }

  void _openScheduleDetail(BuildContext context, StudySchedule schedule) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ScheduleDetailPage(schedule: schedule)),
    ).then((_) => context.read<ScheduleProvider>().load());
  }

  Future<void> _regenerate(BuildContext context, String id) async {
    final schedule = context.read<ScheduleProvider>().schedules.firstWhere(
      (s) => s.id == id,
    );
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Régénérer ?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'L\'IA va recréer un nouvel emploi du temps pour ${StudySchedule.dateRangeLabel(schedule.periodStart, schedule.periodEnd)}. '
          'Les tâches actuelles seront remplacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _RegenerationLoadingDialog(),
      );
      try {
        await context.read<ScheduleProvider>().regenerateSchedule(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Planning régénéré avec succès !'),
              backgroundColor: Theme.of(context).primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(formatUserError(e)),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _delete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Cet emploi du temps et toutes ses tâches seront supprimés définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<ScheduleProvider>().deleteSchedule(id);
    }
  }
}

// ── Card planning ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final StudySchedule schedule;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    required this.onRegenerate,
    required this.onDelete,
  });

  /// Progression de la période : 0.0 → 1.0
  double get _progress {
    final now = DateTime.now();
    final start = schedule.periodStart;
    final end = schedule.periodEnd;
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inMinutes;
    final elapsed = now.difference(start).inMinutes;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get _statusLabel {
    final now = DateTime.now();
    if (now.isBefore(schedule.periodStart)) return 'À venir';
    if (now.isAfter(schedule.periodEnd)) return 'Terminé';
    return 'En cours';
  }

  Color get _statusColor {
    final now = DateTime.now();
    if (now.isBefore(schedule.periodStart)) return const Color(0xFF3498DB);
    if (now.isAfter(schedule.periodEnd)) return Colors.grey;
    return const Color(0xFF2ECC71);
  }

  int get _daysLeft {
    final now = DateTime.now();
    if (now.isAfter(schedule.periodEnd)) return 0;
    return schedule.periodEnd.difference(now).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // ── Contenu principal ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône avec fond coloré
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  schedule.titre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Badge statut
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            StudySchedule.dateRangeLabel(
                              schedule.periodStart,
                              schedule.periodEnd,
                            ),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Chips matières + jours restants
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _chip(
                                '${schedule.subjects.length} matière${schedule.subjects.length > 1 ? 's' : ''}',
                                Icons.book_rounded,
                                isDark,
                              ),
                              if (_daysLeft > 0)
                                _chip(
                                  '$_daysLeft j. restant${_daysLeft > 1 ? 's' : ''}',
                                  Icons.timer_outlined,
                                  isDark,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Menu
                    _CardMenu(
                      isDark: isDark,
                      onEdit: onEdit,
                      onRegenerate: onRegenerate,
                      onDelete: onDelete,
                    ),
                  ],
                ),
              ),
              // ── Barre de progression ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progression',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu contextuel de la card ────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  const _CardMenu({
    required this.isDark,
    required this.onEdit,
    required this.onRegenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'regen') onRegenerate();
        if (v == 'delete') onDelete();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      elevation: 8,
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? Colors.white38 : Colors.black38,
        size: 20,
      ),
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_outlined, 'Modifier', isDark),
        _menuItem('regen', Icons.auto_awesome_rounded, 'Régénérer avec l\'IA', isDark, color: primary),
        const PopupMenuDivider(),
        _menuItem('delete', Icons.delete_outline_rounded, 'Supprimer', isDark, color: Colors.red),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    bool isDark, {
    Color? color,
  }) {
    final c = color ?? (isDark ? Colors.white70 : Colors.black87);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 48,
              color: primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun emploi du temps',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Créez un planning personnalisé avec l\'IA pour organiser vos révisions efficacement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text(
              'Créer mon planning',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog de régénération ────────────────────────────────────────────────────

class _RegenerationLoadingDialog extends StatefulWidget {
  const _RegenerationLoadingDialog();

  @override
  State<_RegenerationLoadingDialog> createState() =>
      _RegenerationLoadingDialogState();
}

class _RegenerationLoadingDialogState
    extends State<_RegenerationLoadingDialog> {
  int _messageIndex = 0;
  late final Timer _timer;

  final List<String> _messages = [
    'Initialisation de la régénération...',
    'Suppression de l\'ancien planning...',
    'Consultation de l\'IA Ngenou...',
    'Analyse de vos préférences...',
    'Optimisation des plages horaires...',
    'Génération des tâches de révision...',
    'Planification des alarmes...',
    'Finalisation de votre emploi du temps...',
  ];

  @override
  void initState() {
    super.initState();
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

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    strokeWidth: 4,
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, size: 26, color: primary),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Régénération en cours',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                _messages[_messageIndex],
                key: ValueKey(_messageIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ),
            const SizedBox(height: 20),
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
