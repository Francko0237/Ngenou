import 'package:flutter/material.dart';
import '../../../core/models/exercice.dart';
import '../../../algo_interpreter/syntax_highlighter.dart';
import '../../../algo_interpreter/interpreter.dart';
import '../../../algo_interpreter/debugger.dart';
import '../../../core/widgets/algo_code_editor.dart';

class EditeurWidget extends StatefulWidget {
  final Exercice exercice;
  final Function(bool) onValidate;

  const EditeurWidget({super.key, required this.exercice, required this.onValidate});

  @override
  _EditeurWidgetState createState() => _EditeurWidgetState();
}

class _EditeurWidgetState extends State<EditeurWidget> {
  late AlgoSyntaxController _controller;
  String _output = "";
  List<AlgoError> _errors = [];
  bool _hasValidated = false;

  @override
  void initState() {
    super.initState();
    _controller = AlgoSyntaxController(text: widget.exercice.codeInitial ?? "");
  }

  void _runCode() async {
    setState(() {
      _output = "";
      _errors = [];
    });
    
    await Interpreter.runCode(
      _controller.text, 
      (out) {
        setState(() => _output += "$out\n");
      }, 
      (promptMsg) async {
        return "5"; // Mock inputs for exercises
      }, 
      (errs) {
        setState(() => _errors = errs);
      }
    );

    setState(() => _hasValidated = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.exercice.question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 16),
        Expanded(
          flex: 3,
          child: AlgoCodeEditor(
            controller: _controller,
            hintText: "Complétez l'algorithme...",
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _controller.clear(),
              icon: const Icon(Icons.clear),
              label: const Text("Effacer"),
            ),
            ElevatedButton.icon(
              onPressed: _runCode,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Exécuter"),
            )
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Terminal Output:", style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _output.isEmpty && _errors.isEmpty
                          ? "..."
                          : "$_output${_errors.isNotEmpty ? '\n--- Erreurs ---\n${_errors.map((e) => e.toString()).join('\n')}' : ''}",
                      style: TextStyle(
                        color: _errors.isNotEmpty ? Colors.red[300] : Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_hasValidated && widget.exercice.explication != null && widget.exercice.explication!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Explication",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.exercice.explication!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: !_hasValidated
                ? null
                : () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      widget.onValidate(_errors.isEmpty);
                    });
                  },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text(
              'Continuer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
              disabledForegroundColor: Colors.grey[500],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: !_hasValidated ? 0 : 2,
            ),
          ),
        ),
      ],
    );
  }
}
