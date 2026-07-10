import 'package:flutter/material.dart';
import '../../core/models/daily_challenge.dart';
import '../../core/widgets/algo_code_editor.dart';
import '../../algo_interpreter/syntax_highlighter.dart';
import '../../algo_interpreter/interpreter.dart';
import '../../algo_interpreter/debugger.dart';

class DailyDefiAlgoSolvePage extends StatefulWidget {
  final DailyChallenge challenge;
  final int challengeIndex;
  final VoidCallback onSolved;
  final VoidCallback onFailed;

  const DailyDefiAlgoSolvePage({
    super.key,
    required this.challenge,
    required this.challengeIndex,
    required this.onSolved,
    required this.onFailed,
  });

  @override
  State<DailyDefiAlgoSolvePage> createState() => _DailyDefiAlgoSolvePageState();
}

class _DailyDefiAlgoSolvePageState extends State<DailyDefiAlgoSolvePage> {
  final AlgoSyntaxController _controller = AlgoSyntaxController();
  final TextEditingController _outputController = TextEditingController();
  List<AlgoError> _errors = [];
  bool _isRunning = false;
  bool _isSolved = false;
  bool _hasSubmitted = false; // Une seule soumission autorisée

  @override
  void initState() {
    super.initState();
    _controller.text = widget.challenge.codeInitial ?? '';
    _isSolved = widget.challenge.isSolved;
    _hasSubmitted = widget.challenge.isSolved || widget.challenge.isFailed; // Déjà soumis si résolu ou échoué
  }

  @override
  void dispose() {
    _controller.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool _compareOutputs(String actual, String expected) {
    String normExpected = expected
        .replaceAll('\\n', '\n')
        .replaceAll('\r\n', '\n')
        .trim();
    String normActual = actual.replaceAll('\r\n', '\n').trim();
    List<String> expLines = normExpected
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    List<String> actLines = normActual
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (expLines.length != actLines.length) return false;
    for (int i = 0; i < expLines.length; i++) {
      if (expLines[i].replaceAll(' ', '').toLowerCase() !=
          actLines[i].replaceAll(' ', '').toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  void _showSolution(String solution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Solution correcte'),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              solution,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
    if (_hasSubmitted) return; // Une seule tentative autorisée
    setState(() {
      _isRunning = true;
      _hasSubmitted = true;
      _outputController.text = 'Évaluation en cours…\n';
      _errors = [];
    });

    final tests = widget.challenge.algoTests ?? [];
    if (tests.isEmpty) {
      // Pas de tests automatiques : on exécute le code pour vérifier qu'il tourne.
      final code = _controller.text.trim();

      // Détecter si l'utilisateur n'a rien ajouté (squelette vide)
      final codeNormalized = code
          .replaceAll('\r\n', '\n')
          .replaceAll(RegExp(r'\n\s*\n'), '\n')
          .trim();
      final initialNormalized = (widget.challenge.codeInitial ?? '')
          .replaceAll('\r\n', '\n')
          .replaceAll(RegExp(r'\n\s*\n'), '\n')
          .trim();

      if (code.isEmpty || codeNormalized == initialNormalized) {
        setState(() {
          _isRunning = false;
          _hasSubmitted = false; // Permettre une nouvelle tentative
          _outputController.text =
              '⚠️ Vous n\'avez pas encore écrit de solution.\nComplétez le code entre Debut et Fin.';
        });
        return;
      }

      String executionOutput = '';
      List<AlgoError> executionErrors = [];
      await Interpreter.runCode(code, (out) => executionOutput += '$out\n', (
        promptMsg,
      ) async {
        // Vraie saisie interactive — même comportement que le bouton "Tester"
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
      }, (errs) => executionErrors = errs);

      if (executionErrors.isNotEmpty) {
        setState(() {
          _isRunning = false;
          _isSolved = false;
          _errors = executionErrors;
          _outputController.text =
              '❌ Votre code contient des erreurs :\n'
              '${executionErrors.map((e) => e.toString()).join('\n')}';
        });
        widget.onFailed();
        return;
      }

      setState(() {
        _isRunning = false;
        _isSolved = true;
        _outputController.text =
            '✅ Code exécuté avec succès !\n\n$executionOutput';
      });
      widget.onSolved();
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Défi validé ! 🎉'),
            content: const Text(
              'Votre code s\'exécute correctement. Défi réussi !',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text('Continuer'),
              ),
            ],
          ),
        );
      }
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
        setState(() {
          _outputController.text += '❌ Test ${i + 1}: Erreur de code.\n';
          _errors.addAll(executionErrors);
        });
        continue;
      }

      if (_compareOutputs(executionOutput, test.expectedOutput)) {
        setState(() => _outputController.text += '✅ Test ${i + 1}: Réussi !\n');
        passed++;
      } else {
        final cleanExpected = test.expectedOutput
            .replaceAll('\\n', '\n')
            .trim();
        setState(
          () => _outputController.text +=
              '❌ Test ${i + 1}: Échec.\n   Attendu  : "$cleanExpected"\n   Obtenu   : "${executionOutput.trim()}"\n',
        );
      }
    }

    final allPassed = passed == tests.length;
    setState(() {
      _isRunning = false;
      _isSolved = allPassed;
      _outputController.text +=
          '\n=== RÉSULTAT FINAL ===\n$passed / ${tests.length} tests réussis\n';
      if (!allPassed) {
        // Afficher ce qui était attendu pour chaque test raté
        final failedTests = tests.asMap().entries.where((e) {
          final i = e.key;
          return !_outputController.text.contains('✅ Test ${i + 1}');
        }).toList();

        if (failedTests.isNotEmpty) {
          _outputController.text +=
              '\n── Ce que votre code aurait dû produire ──\n';
          for (final entry in failedTests) {
            final i = entry.key;
            final t = entry.value;
            final cleanExpected = t.expectedOutput
                .replaceAll('\\n', '\n')
                .trim();
            final inputs = t.inputs.isNotEmpty
                ? 'Entrées : ${t.inputs.join(', ')}\n   '
                : '';
            _outputController.text +=
                'Test ${i + 1} : ${inputs}Sortie attendue : "$cleanExpected"\n';
          }
        }
        _outputController.text += '\nRelisez l\'énoncé et réessayez.';
      }
    });

    // Après un échec, proposer de voir la solution
    if (!allPassed && mounted) {
      final solution = widget.challenge.codeSolution;
      if (solution != null && solution.isNotEmpty) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Défi non réussi'),
            content: const Text('Voulez-vous voir la solution correcte ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Continuer à essayer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(c);
                  _showSolution(solution);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Voir la solution'),
              ),
            ],
          ),
        );
      }
    }

    if (allPassed) {
      widget.onSolved();
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Défi validé ! 🎉'),
            content: const Text(
              'Félicitations, vous avez résolu ce défi algorithmique avec succès !',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text('Continuer'),
              ),
            ],
          ),
        );
      }
    } else {
      widget.onFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    // ── Layout en 4 zones fixes — aucun espace vide ──────────────────────────
    //  Zone 1 : En-tête compact scrollable  (maxHeight = 22 % écran)
    //  Zone 2 : Éditeur de code             (Expanded flex 3)
    //  Zone 3 : Boutons Tester / Soumettre  (hauteur fixe)
    //  Zone 4 : Terminal                    (Expanded flex 2 → grandit quand
    //                                        le clavier est replié)

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Défi #${widget.challengeIndex + 1} : Algorithme'),
      ),
      // resizeToAvoidBottomInset = true (défaut) : Flutter réduit la hauteur
      // du body quand le clavier apparaît, donc les 4 zones se répartissent
      // dans l'espace disponible sans laisser de blanc.
      body: SafeArea(
        child: Column(
          children: [
            // ── Zone 1 : En-tête ─────────────────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.22,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags matière + résolu
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
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
                        if (_isSolved) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Résolu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_hasSubmitted && !_isSolved) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.red,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Incorrect',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Titre de la question
                    Text(
                      widget.challenge.question,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Énoncé
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        widget.challenge.explication,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Zone 2 : Éditeur de code ──────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AlgoCodeEditor(
                    controller: _controller,
                    hintText: 'Codez votre solution ici…',
                  ),
                ),
              ),
            ),

            // ── Zone 3 : Boutons Tester / Soumettre ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isRunning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Tester'),
                      onPressed: _isRunning ? null : _tester,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isRunning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _hasSubmitted
                                  ? Icons.lock_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                            ),
                      label: Text(_hasSubmitted ? 'Soumis' : 'Soumettre'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasSubmitted ? Colors.grey : primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (_isRunning || _hasSubmitted)
                          ? null
                          : _soumettre,
                    ),
                  ),
                ],
              ),
            ),

            // ── Zone 4 : Terminal — remplit tout l'espace restant ─────────
            // Avec flex: 2 sur l'éditeur (flex: 3), le terminal prend ~40 %
            // de l'espace flexible. Quand le clavier est replié, il devient
            // plus grand automatiquement — aucun espace blanc résiduel.
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre titre du terminal
                    Row(
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          size: 12,
                          color: isDark
                              ? Colors.greenAccent
                              : Colors.green[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Terminal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.greenAccent
                                : Colors.green[800],
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        if (_isRunning)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Sortie — occupe tout l'espace restant, scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _outputController,
                          builder: (context, value, _) {
                            final text = value.text.isEmpty && _errors.isEmpty
                                ? '…'
                                : '${value.text}${_errors.isNotEmpty ? '\n--- Erreurs ---\n${_errors.map((e) => e.toString()).join('\n')}' : ''}';
                            return Text(
                              text,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: _errors.isNotEmpty
                                    ? (isDark
                                          ? Colors.red[300]
                                          : Colors.red[800])
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
