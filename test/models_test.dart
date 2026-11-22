import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou/core/models/score.dart';
import 'package:ngenou/core/models/study_task.dart';
import 'package:ngenou/core/models/task_priority.dart';
import 'package:ngenou/core/models/progression.dart';

void main() {
  group('Score Model Tests', () {
    test('Score serialization and percentage calculation', () {
      final now = DateTime.now();
      final score = Score(
        id: 1,
        matiereId: 'algo',
        notionId: 'notion_1',
        exerciceId: 'ex_1',
        score: 8,
        total: 10,
        pourcentage: 80.0,
        dateTentative: now,
        tentativeNum: 1,
      );

      final map = score.toMap();
      expect(map['matiere_id'], 'algo');
      expect(map['score'], 8);
      expect(map['total'], 10);
      expect(map['pourcentage'], 80.0);

      final restored = Score.fromMap(map);
      expect(restored.matiereId, score.matiereId);
      expect(restored.score, score.score);
      expect(restored.total, score.total);
      expect(restored.pourcentage, score.pourcentage);
    });
  });

  group('StudyTask Model Tests', () {
    test('StudyTask priority and status helpers', () {
      final task = StudyTask(
        id: 'task_123',
        scheduleId: 'sched_1',
        matiereId: 'algo',
        matiereNom: 'Algorithmique',
        title: 'Réviser les boucles',
        scheduledAt: DateTime.parse('2026-11-25 14:00:00'),
        durationMinutes: 45,
        status: TaskStatus.pending,
        priority: TaskPriority.urgent,
      );

      expect(task.isPending, isTrue);
      expect(task.status == TaskStatus.completed, isFalse);

      final updated = task.copyWith(status: TaskStatus.completed);
      expect(updated.status == TaskStatus.completed, isTrue);
      expect(updated.isPending, isFalse);
    });
  });

  group('Progression Model Tests', () {
    test('Progression percentage and completion calculation', () {
      final prog = Progression(
        id: 1,
        matiereId: 'algo',
        notionId: 'notion_1',
        statut: 'en_cours',
        nbExercicesReussis: 3,
        nbExercicesTotal: 5,
        progressionLecture: 0.6,
      );

      expect(prog.nbExercicesReussis, 3);
      expect(prog.nbExercicesTotal, 5);
      expect(prog.progressionLecture, 0.6);
    });
  });
}

