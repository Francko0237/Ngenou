import 'package:flutter/material.dart';
import '../../algo_interpreter/syntax_highlighter.dart';
import '../../algo_interpreter/interpreter.dart';
import '../../algo_interpreter/debugger.dart';
import '../../core/database/database_helper.dart';
import '../../core/widgets/algo_code_editor.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final AlgoSyntaxController _controller = AlgoSyntaxController();
  final TextEditingController _outputController = TextEditingController();
  final GlobalKey _editorKey = GlobalKey();
  List<AlgoError> _errors = [];
  bool _isRunning = false;
  List<Map<String, dynamic>> _savedCodes = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCodes();
  }

  Future<void> _loadSavedCodes() async {
    final codes = await DatabaseHelper.instance.getCodesSauvegardes();
    setState(() => _savedCodes = codes);
  }

  final Map<String, String> exemples = {
    "Hello World": '''Algorithme HelloWorld;
Debut
   Ecrire("Bonjour le monde !");
Fin''',
    "Factorielle": '''Algorithme Factorielle;
Var
   n, i, resultat : Entier;
Debut
   Ecrire("Entrez un entier positif : ");
   Lire(n);
   resultat ← 1;
   Pour i ← 1 a n Faire
      resultat ← resultat * i;
   FinPour;
   Ecrire("Factorielle de ", n, " = ", resultat);
Fin''',
    "Tri à bulles": '''Algorithme TriBulles;
Var
   T : Tableau[1..5] de Entier;
   i, j, temp : Entier;
Debut
   T[1] ← 64;
   T[2] ← 25;
   T[3] ← 12;
   T[4] ← 22;
   T[5] ← 11;
   Pour i ← 1 a 4 Faire
      Pour j ← 1 a 5-i Faire
         Si (T[j] > T[j+1]) Alors
            temp ← T[j];
            T[j] ← T[j+1];
            T[j+1] ← temp;
         FinSi;
      FinPour;
   FinPour;
   Pour i ← 1 a 5 Faire
      Ecrire(T[i]);
   FinPour;
Fin''',
    "Recherche dichotomique": '''Algorithme RechercheDicho;
Var
   T : Tableau[1..7] de Entier;
   cible, gauche, droite, milieu : Entier;
   trouve : Booléen;
Debut
   T[1]←1; T[2]←3; T[3]←5; T[4]←7; T[5]←9; T[6]←11; T[7]←13;
   Ecrire("Valeur à chercher : ");
   Lire(cible);
   gauche ← 1;
   droite ← 7;
   trouve ← Faux;
   Tant que (gauche ≤ droite ET NON trouve) Faire
      milieu ← (gauche + droite) DIV 2;
      Si (T[milieu] = cible) Alors
         trouve ← Vrai;
      Sinon
         Si (T[milieu] < cible) Alors
            gauche ← milieu + 1;
         Sinon
            droite ← milieu - 1;
         FinSi;
      FinSi;
   FinTantQue;
   Si (trouve) Alors
      Ecrire("Trouvé à l'indice ", milieu);
   Sinon
      Ecrire("Non trouvé");
   FinSi;
Fin''',
  };

  void _loadCodeString(String codeText) {
    setState(() {
      _controller.text = codeText;
      _outputController.text = "";
      _errors = [];
    });
  }

  void _runCode() async {
    setState(() {
      _isRunning = true;
      _outputController.text = "";
      _errors = [];
    });

    await Interpreter.runCode(
      _controller.text,
      (out) {
        setState(() => _outputController.text += "$out\n");
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

    if (_controller.text.trim().isNotEmpty) {
      DatabaseHelper.instance.insertHistoriqueTerminal(
        _controller.text,
        _outputController.text,
      );
    }

    setState(() {
      _isRunning = false;
    });
  }

  void _showScriptsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Mes Scripts & Exemples",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Exemples",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...exemples.keys.map(
                            (k) => ListTile(
                              leading: const Icon(Icons.code),
                              title: Text(k),
                              onTap: () {
                                Navigator.pop(context);
                                _loadCodeString(exemples[k]!);
                              },
                            ),
                          ),
                          if (_savedCodes.isNotEmpty) ...[
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "Mes Sauvegardes",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ..._savedCodes.map(
                              (s) => ListTile(
                                leading: const Icon(Icons.save),
                                title: Text(s['nom'] as String),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Supprimer"),
                                        content: Text(
                                          "Voulez-vous vraiment supprimer '${s['nom']}' ?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text("Annuler"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text(
                                              "Supprimer",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await DatabaseHelper.instance
                                          .deleteCodeSauvegarde(s['id'] as int);
                                      await _loadSavedCodes();
                                      setModalState(
                                        () {},
                                      ); // update the bottom sheet
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "${s['nom']} supprimé",
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _loadCodeString(s['code'] as String);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final int editorFlex = isKeyboardOpen ? 1 : (isTablet ? 6 : 5);
    final int outputFlex = isTablet ? 2 : 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Algo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Sauvegarder',
            onPressed: () async {
              if (_controller.text.trim().isEmpty) return;
              String nom = "";
              await showDialog(
                context: context,
                builder: (context) {
                  final tCtrl = TextEditingController();
                  return AlertDialog(
                    title: const Text("Sauvegarder ce script"),
                    content: TextField(
                      controller: tCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Nom du script",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Annuler"),
                      ),
                      TextButton(
                        onPressed: () {
                          nom = tCtrl.text;
                          Navigator.pop(context);
                        },
                        child: const Text("Enregistrer"),
                      ),
                    ],
                  );
                },
              );
              if (nom.trim().isNotEmpty) {
                await DatabaseHelper.instance.insertCodeSauvegarde(
                  nom.trim(),
                  _controller.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$nom enregistré avec succès")),
                  );
                }
                _loadSavedCodes();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Mes Scripts & Exemples',
            onPressed: _showScriptsModal,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            Expanded(
              flex: editorFlex,
              child: AlgoCodeEditor(
                key: _editorKey,
                controller: _controller,
                hintText: "Tapez votre algorithme ici...",
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: _isRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: const Text("Exécuter", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: _isRunning ? null : _runCode,
              ),
            ),
            if (!isKeyboardOpen) ...[
              Expanded(
                flex: outputFlex,
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
                        "Sortie Terminal :",
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
