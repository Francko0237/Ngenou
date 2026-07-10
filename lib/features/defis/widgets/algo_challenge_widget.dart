import 'package:flutter/material.dart';
import '../../../core/models/daily_challenge.dart';
import '../../../core/widgets/algo_code_editor.dart';
import '../../../algo_interpreter/syntax_highlighter.dart';
import '../../../algo_interpreter/interpreter.dart';
import '../../../algo_interpreter/debugger.dart';

/// Widget pour résoudre un défi algorithmique dans la page des défis quotidiens.
/// Intègre un éditeur de code et le terminal d'exécution.
class AlgoChallengeWidget extends StatefulWidget {
  final DailyChallenge challenge;
  final int challengeIndex;
  final VoidCallback onSolved;
  final VoidCallback onNext;

  const AlgoChallengeWidget({
    super.key,
    required this.challenge,
    required this.challengeIndex,
    required this.onSolved,
    required this.onNext,
  });

  @override
  State<AlgoChallengeWidget> createState() => _AlgoChallengeWidgetState();
}

class _AlgoChallengeWidgetState extends State<AlgoChallengeWidget> {
  final AlgoSyntaxController _controller = AlgoSyntaxController();
  final TextEditingController _outputController = TextEditingController();
  List<AlgoError> _errors = [];
  bool _isRunning = false;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.challenge.codeInitial ?? '';
    _isSolved = widget.challenge.isSolved;
  }

  @override
  void dispose() {
    _controller.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool _compareOutputs(String actual, String expected) {
    String normExpected = expected.replaceAll('\\n', '\n').replaceAll('\r\n', '\n').trim();
    String normActual = actual.replaceAll('\r\n', '\n').trim();
    List<String> expLines = normExpected.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    List<String> actLines = normActual.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (expLines.length != actLines.length) return false;
    for (int i = 0; i < expLines.length; i++) {
      if (expLines[i].replaceAll(' ', '').toLowerCase() != actLines[i].replaceAll(' ', '').toLowerCase()) return false;
    }
    return true;
  }

  Future<void> _tester() async {
    setState(() {
      _isRunning = true;
      _outputController.text = '';
      _errors = [];
    });

    await Interpreter.runCode(
      _controller.text,
      (out) => setState(() => _outputController.text += '$out\n'),
      (promptMsg) async {
        String prompt = promptMsg ?? 'Saisie attendue';
        String type = 'texte';
        if (promptMsg != null && promptMsg.contains('|')) {
          final parts = promptMsg.split('|');
          prompt = parts[0];
          type = parts[1].toLowerCase();
        }

        String result = '';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final tCtrl = TextEditingController();
            String? errorText;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                bool validerSaisie() {
                  final val = tCtrl.text.trim();
                  if (val.isEmpty) {
                    setDialogState(() => errorText = 'La valeur ne peut pas être vide');
                    return false;
                  }
                  if (type == 'entier') {
                    if (int.tryParse(val) == null) {
                      setDialogState(() => errorText = 'Veuillez saisir un entier valide');
                      return false;
                    }
                  } else if (type == 'réel' || type == 'reel') {
                    if (double.tryParse(val) == null) {
                      setDialogState(() => errorText = 'Veuillez saisir un nombre réel valide');
                      return false;
                    }
                  } else if (type == 'booléen' || type == 'booleen') {
                    final lower = val.toLowerCase();
                    if (lower != 'vrai' && lower != 'faux' && lower != 'true' && lower != 'false') {
                      setDialogState(() => errorText = 'Veuillez saisir vrai ou faux');
                      return false;
                    }
                  }
                  result = val;
                  return true;
                }

                return AlertDialog(
                  title: Text(prompt),
                  content: TextField(
                    controller: tCtrl,
                    autofocus: true,
                    keyboardType: (type == 'entier' || type == 'réel' || type == 'reel')
                        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                      errorText: errorText,
                      hintText: 'Entrez une valeur',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (validerSaisie()) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        if (validerSaisie()) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Valider'),
                    ),
                  ],
                );
              },
            );
          },
        );
        return result.isEmpty ? '0' : result;
      },
      (errs) => setState(() => _errors = errs),
    );

    setState(() => _isRunning = false);
  }

  Future<void> _soumettre() async {
    setState(() {
      _isRunning = true;
      _outputController.text = 'Évaluation en cours…\n';
      _errors = [];
    });

    final tests = widget.challenge.algoTests ?? [];
    if (tests.isEmpty) {
      setState(() {
        _isRunning = false;
        _outputController.text = 'Aucun test automatique défini.\n✅ Exercice validé manuellement.';
        _isSolved = true;
      });
      widget.onSolved();
      return;
    }

    int passed = 0;
    for (int i = 0; i < tests.length; i++) {
      final test = tests[i];
      String executionOutput = '';
      int inputIndex = 0;
      List<AlgoError> executionErrors = [];

      await Interpreter.runCode(
        _controller.text,
        (out) => executionOutput += '$out\n',
        (prompt) async {
          if (inputIndex < test.inputs.length) return test.inputs[inputIndex++];
          return '0';
        },
        (errs) => executionErrors = errs,
      );

      if (executionErrors.isNotEmpty) {
        setState(() => _outputController.text += '❌ Test ${i + 1}: Erreur syntaxe/exécution.\n');
        setState(() => _errors.addAll(executionErrors));
        continue;
      }

      if (_compareOutputs(executionOutput, test.expectedOutput)) {
        setState(() => _outputController.text += '✅ Test ${i + 1}: Réussi !\n');
        passed++;
      } else {
        final cleanExpected = test.expectedOutput.replaceAll('\\n', '\n').trim();
        setState(() => _outputController.text +=
            '❌ Test ${i + 1}: Échec. Attendu "$cleanExpected", Obtenu "${executionOutput.trim()}"\n');
      }
    }

    setState(() {
      _isRunning = false;
      _outputController.text += '\n=== RÉSULTAT ===\n$passed / ${tests.length} tests réussis';
    });

    if (passed == tests.length) {
      setState(() => _isSolved = true);
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Matière tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.challenge.matiereNom,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Titre
        Text(
          widget.challenge.question,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Énoncé
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
          ),
          child: Text(
            widget.challenge.explication,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Éditeur de code
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: AlgoCodeEditor(
              controller: _controller,
              hintText: 'Codez votre solution ici…',
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Boutons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: _isRunning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Tester'),
                onPressed: _isRunning ? null : _tester,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: _isRunning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Soumettre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isRunning ? null : _soumettre,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Terminal output
        Container(
          width: double.infinity,
          height: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terminal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.greenAccent : Colors.green[800],
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _outputController,
                  builder: (context, value, _) {
                    final text = value.text.isEmpty && _errors.isEmpty
                        ? '…'
                        : '${value.text}${_errors.isNotEmpty ? '\n--- Erreurs ---\n${_errors.map((e) => e.toString()).join('\n')}' : ''}';
                    return SingleChildScrollView(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: _errors.isNotEmpty
                              ? (isDark ? Colors.red[300] : Colors.red[800])
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Bouton suivant si résolu
        if (_isSolved) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Exercice validé ! 🎉',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onNext,
                  child: const Text('Suivant →'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
