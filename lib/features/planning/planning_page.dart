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
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Emploi du temps',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Nouveau planning'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Text(
                    'Sélectionnez un planning pour voir le détail jour par jour.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (provider.schedules.isEmpty)
                    _EmptyState(onCreate: () => _openWizard(context))
                  else
                    ...provider.schedules.map(
                      (s) => _ScheduleCard(
                        schedule: s,
                        primary: primary,
                        isDark: isDark,
                        onTap: () => _openScheduleDetail(context, s),
                        onEdit: () => _openEditWizard(context, s),
                        onRegenerate: () => _regenerate(context, s.id),
                        onDelete: () => _delete(context, s.id),
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
        title: const Text('Régénérer ?'),
        content: Text(
          'L\'IA va recréer un nouvel emploi du temps pour ${StudySchedule.dateRangeLabel(schedule.periodStart, schedule.periodEnd)}. '
          'Les tâches actuelles seront remplacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
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
            const SnackBar(
              content: Text('Emploi du temps régénéré avec succès !'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(formatUserError(e))));
        }
      } finally {
        if (context.mounted) {
          Navigator.pop(context); // Fermer le dialogue de chargement
        }
      }
    }
  }

  Future<void> _delete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text(
          'Cet emploi du temps et toutes ses tâches seront supprimés.',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.titre,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        StudySchedule.dateRangeLabel(
                          schedule.periodStart,
                          schedule.periodEnd,
                        ),
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${schedule.subjects.length} matière(s) · ${schedule.isActive ? 'Actif' : 'Inactif'}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'regen') onRegenerate();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                      value: 'regen',
                      child: Text('Régénérer avec l\'IA'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
                Icon(Icons.chevron_right_rounded, color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.event_note_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Aucun emploi du temps',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez un planning personnalisé avec l\'IA\npour organiser vos révisions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Créer mon emploi du temps'),
          ),
        ],
      ),
    );
  }
}

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
    'Finalisation de votre nouvel emploi du temps...',
    'Presque terminé, veuillez patienter...',
  ];

  @override
  void initState() {
    super.initState();
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

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 70,
                    width: 70,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                      strokeWidth: 5,
                    ),
                  ),
                  Icon(Icons.auto_awesome, size: 30, color: primary),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Régénération en cours',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey<int>(_messageIndex),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
