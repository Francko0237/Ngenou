import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/exercice.dart';
import '../../core/models/score.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/database/database_helper.dart';
import '../../modules/modules_registry.dart';
import 'widgets/qcm_widget.dart';
import 'widgets/editeur_widget.dart';

class ExercicePage extends StatefulWidget {
  final String matiereId;
  final String notionId;
  final int index;
  final int currentScore;

  const ExercicePage({
    super.key,
    required this.matiereId,
    required this.notionId,
    required this.index,
    this.currentScore = 0,
  });

  @override
  State<ExercicePage> createState() => _ExercicePageState();
}

class _ExercicePageState extends State<ExercicePage> {
  late List<Exercice> _exercices;
  late int _currentIndex;
  late int _score;

  @override
  void initState() {
    super.initState();
    _exercices = ModulesRegistry.getExercicesByNotion(widget.matiereId, widget.notionId)
        .where((e) => e.type != TypeExercice.qro)
        .toList();
    _currentIndex = widget.index.clamp(0, _exercices.isNotEmpty ? _exercices.length - 1 : 0);
    _score = widget.currentScore;
  }

  void _onValidate(bool success) async {
    if (success) _score++;

    await context.read<ProgressionProvider>().saveTestResult(
          widget.matiereId,
          widget.notionId,
          success,
        );

    if (_currentIndex < _exercices.length - 1) {
      setState(() => _currentIndex++);
    } else {
      final total = _exercices.length;
      final pourcentage = total > 0 ? (_score / total) * 100 : 0.0;
      final score = Score(
        matiereId: widget.matiereId,
        notionId: widget.notionId,
        exerciceId: _exercices.last.id,
        score: _score,
        total: total,
        pourcentage: pourcentage,
        dateTentative: DateTime.now(),
        tentativeNum: 1,
      );
      await DatabaseHelper.instance.insertScore(score);
      if (mounted) {
        context.push('/resultat', extra: score);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exercices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercices')),
        body: const Center(child: Text('Aucun exercice pour cette notion.')),
      );
    }

    final exercice = _exercices[_currentIndex];
    final progress = (_currentIndex + 1) / _exercices.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercice ${_currentIndex + 1} / ${_exercices.length}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _buildWidget(exercice),
        ),
      ),
    );
  }

  Widget _buildWidget(Exercice exercice) {
    // ValueKey: un State par exercice. Sans clé, Flutter réutilise le State du
    // QCM précédent (_hasValidated, _selectedIndex) → blocage et faux "clics".
    final key = ValueKey<String>(exercice.id);
    switch (exercice.type) {
      case TypeExercice.qro:
        return const SizedBox.shrink();
      case TypeExercice.editeur:
        return EditeurWidget(
          key: key,
          exercice: exercice,
          onValidate: _onValidate,
        );
      case TypeExercice.qcm:
        return QcmWidget(key: key, exercice: exercice, onValidate: _onValidate);
    }
  }
}
