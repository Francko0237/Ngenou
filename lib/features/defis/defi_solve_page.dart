import 'package:flutter/material.dart';
import '../../core/models/defi.dart';
import '../../algo_interpreter/syntax_highlighter.dart';
import '../../algo_interpreter/interpreter.dart';
import '../../algo_interpreter/debugger.dart';
import '../../core/widgets/algo_code_editor.dart';

class DefiSolvePage extends StatefulWidget {
  final Defi defi;
  const DefiSolvePage({super.key, required this.defi});

  @override
  _DefiSolvePageState createState() => _DefiSolvePageState();
}

class _DefiSolvePageState extends State<DefiSolvePage> {
  final AlgoSyntaxController _controller = AlgoSyntaxController();
  final TextEditingController _outputController = TextEditingController();
  final GlobalKey _editorKey = GlobalKey();
  List<AlgoError> _errors = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.defi.codeInitial;
  }

  void _testerMAnuellement() async {
    setState(() {
      _isRunning = true;
      _outputController.text = "";
      _errors = [];
    });

    await Interpreter.runCode(
      _controller.text,
      (out) {
        _outputController.text += "$out\n";
      },
      (promptMsg) async {
        String prompt = promptMsg ?? "Saisie attendue";
        String type = "texte";
        if (promptMsg != null && promptMsg.contains('|')) {
          final parts = promptMsg.split('|');
          prompt = parts[0];
          type = parts[1].toLowerCase();
        }

        String result = "";
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
                      child: const Text("Valider"),
                    ),
                  ],
                );
              },
            );
          },
        );
        return result.isEmpty ? "0" : result;
      },
      (errs) {
        setState(() => _errors = errs);
      },
    );

    setState(() => _isRunning = false);
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
      String cleanExp = expLines[i].replaceAll(' ', '').toLowerCase();
      String cleanAct = actLines[i].replaceAll(' ', '').toLowerCase();
      if (cleanExp != cleanAct) return false;
    }
    return true;
  }

  void _soumettreAutomatiquement() async {
    setState(() {
      _isRunning = true;
      _outputController.text = "Évaluation en cours...\n";
      _errors = [];
    });

    int passed = 0;

    for (int i = 0; i < widget.defi.tests.length; i++) {
      final test = widget.defi.tests[i];
      String executionOutput = "";
      int inputIndex = 0;
      List<AlgoError> executionErrors = [];

      await Interpreter.runCode(
        _controller.text,
        (out) => executionOutput += "$out\n",
        (prompt) async {
          if (inputIndex < test.inputs.length) {
            return test.inputs[inputIndex++];
          }
          return "0";
        },
        (errs) => executionErrors = errs,
      );

      if (executionErrors.isNotEmpty) {
        _outputController.text +=
            "❌ Test ${i + 1}: Erreur de syntaxe/exécution.\n";
        setState(() => _errors.addAll(executionErrors));
        continue;
      }

      if (_compareOutputs(executionOutput, test.expectedOutput)) {
        _outputController.text += "✅ Test ${i + 1}: Réussi !\n";
        passed++;
      } else {
        String cleanExpected = test.expectedOutput
            .replaceAll('\\n', '\n')
            .trim();
        String cleanActual = executionOutput.trim();
        _outputController.text +=
            "❌ Test ${i + 1}: Échec. Attendu '$cleanExpected', Obtenu '$cleanActual'\n";
      }
    }

    int score = (passed / widget.defi.tests.length * 10).toInt();
    setState(() {
      _isRunning = false;
      _outputController.text +=
          "\n=== RÉSULTAT FINAL ===\nScore : $score / 10\n";
    });

    if (passed == widget.defi.tests.length) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Défi accompli ! 🎉"),
          content: const Text(
            "Félicitations, vous avez validé ce défi avec 10/10 !",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context, true); // true = défi résolu avec succès
              },
              child: const Text("Continuer"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text("Défi: ${widget.defi.titre}")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            if (!isKeyboardOpen) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  widget.defi.description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              flex: isKeyboardOpen ? 1 : 4,
              child: AlgoCodeEditor(
                key: _editorKey,
                controller: _controller,
                hintText: "Codez la solution ici...",
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: _isRunning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bug_report, size: 16),
                  label: const Text("Tester", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: _isRunning ? null : _testerMAnuellement,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: _isRunning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text(
                    "Soumettre",
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: _isRunning ? null : _soumettreAutomatiquement,
                ),
              ],
            ),
            if (!isKeyboardOpen) ...[
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Résultat Évaluation :",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.greenAccent
                              : Colors.green[800],
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _outputController,
                          builder: (context, value, child) {
                            final textToShow =
                                value.text.isEmpty && _errors.isEmpty
                                ? "..."
                                : "${value.text}${_errors.isNotEmpty ? '\n--- Erreurs ---\n${_errors.map((e) => e.toString()).join('\n')}' : ''}";

                            return TextField(
                              controller: TextEditingController(
                                text: textToShow,
                              ),
                              readOnly: true,
                              maxLines: null,
                              expands: true,
                              style: TextStyle(
                                fontSize: 13,
                                color: _errors.isNotEmpty
                                    ? (isDark
                                          ? Colors.red[300]
                                          : Colors.red[800])
                                    : (isDark ? Colors.white : Colors.black87),
                                fontFamily: 'monospace',
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
