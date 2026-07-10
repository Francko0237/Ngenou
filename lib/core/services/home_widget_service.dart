import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/study_task.dart';
import '../../features/tasks/task_format.dart';
import '../database/database_helper.dart';

/// Identifiant de l'application utilisé par home_widget pour les SharedPreferences Android
/// et le App Group iOS.
const _kAppGroupId = 'group.com.ngenou.app';
const _kAndroidWidget = 'com.ngenou.app.TaskListWidget';
const _kAndroidChallengeWidget = 'com.ngenou.app.DailyChallengeWidget';

/// Pousse les données des tâches d'aujourd'hui vers les widgets natifs (Android/iOS).
///
/// Appelé après chaque mutation de tâche dans [ScheduleProvider].
class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  Future<void> init() async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(_kAppGroupId);
    } catch (e) {
      debugPrint('HomeWidgetService.init error (non-fatal): $e');
    }
  }

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Met à jour les données des widgets avec la liste de tâches d'aujourd'hui et les défis.
  Future<void> updateTasksWidget(List<StudyTask> todayTasks) async {
    if (!_supported) return;

    try {
      final now = DateTime.now();
      final pendingTasks =
          todayTasks
              .where((t) => t.isPending && (t.isStudyActivity || t.isManual))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      final doneCount = todayTasks
          .where((t) => t.status == TaskStatus.completed)
          .length;

      final dateLabel = _buildDateLabel(now);

      // Données globales
      await HomeWidget.saveWidgetData<String>('widget_date', dateLabel);
      await HomeWidget.saveWidgetData<int>(
        'widget_task_count',
        pendingTasks.length,
      );
      await HomeWidget.saveWidgetData<int>('widget_done_count', doneCount);

      // Tâches individuelles (max 3 affichées)
      for (int i = 0; i < 3; i++) {
        if (i < pendingTasks.length) {
          final task = pendingTasks[i];
          await HomeWidget.saveWidgetData<String>(
            'widget_task_title_$i',
            task.displayTitle,
          );
          await HomeWidget.saveWidgetData<String>(
            'widget_task_time_$i',
            TaskFormat.time(task.scheduledAt),
          );
        } else {
          // Effacer les slots inutilisés
          await HomeWidget.saveWidgetData<String?>(
            'widget_task_title_$i',
            null,
          );
          await HomeWidget.saveWidgetData<String?>('widget_task_time_$i', null);
        }
      }

      // Données du défi quotidien
      final todayStr = now.toIso8601String().substring(0, 10);
      final challengeSession =
          await DatabaseHelper.instance.getDailyChallengeSessionForDate(todayStr);

      if (challengeSession == null) {
        await HomeWidget.saveWidgetData<int>('challenge_count', 0);
        await HomeWidget.saveWidgetData<int>('challenge_score', 0);
        await HomeWidget.saveWidgetData<int>('challenge_total', 0);
        for (int i = 0; i < 3; i++) {
          await HomeWidget.saveWidgetData<String?>('challenge_q_$i', null);
          await HomeWidget.saveWidgetData<bool>('challenge_answered_$i', false);
        }
      } else {
        final challenges = challengeSession.challenges;
        final displayCount = challenges.length.clamp(0, 3);

        await HomeWidget.saveWidgetData<int>('challenge_count', displayCount);
        await HomeWidget.saveWidgetData<int>('challenge_score', challengeSession.score);
        await HomeWidget.saveWidgetData<int>('challenge_total', challengeSession.total);

        for (int i = 0; i < 3; i++) {
          if (i < challenges.length) {
            final c = challenges[i];
            final typeTag = c.type == 'algo' ? 'ALGO' : 'QCM';
            final q = c.question.length > 42
                ? '${c.question.substring(0, 39)}...'
                : c.question;
            final answered = c.type == 'qcm'
                ? c.userAnswerIndex != null
                : c.isSolved || c.isFailed;
            await HomeWidget.saveWidgetData<String>('challenge_q_$i', '[$typeTag] $q');
            await HomeWidget.saveWidgetData<bool>('challenge_answered_$i', answered);
          } else {
            await HomeWidget.saveWidgetData<String?>('challenge_q_$i', null);
            await HomeWidget.saveWidgetData<bool>('challenge_answered_$i', false);
          }
        }
      }

      // Demande la mise à jour des widgets natifs
      await HomeWidget.updateWidget(
        androidName: _kAndroidWidget,
        qualifiedAndroidName: _kAndroidWidget,
      );
      await HomeWidget.updateWidget(
        androidName: _kAndroidChallengeWidget,
        qualifiedAndroidName: _kAndroidChallengeWidget,
      );
    } catch (e) {
      debugPrint('HomeWidgetService.updateTasksWidget error (non-fatal): $e');
    }
  }

  String _buildDateLabel(DateTime d) {
    const months = [
      'jan.',
      'fév.',
      'mar.',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sep.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return 'Aujourd\'hui · ${d.day} ${months[d.month - 1]}';
  }
}
