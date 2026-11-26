import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../algo_interpreter/file_storage.dart';
import '../../algo_interpreter/syntax_highlighter.dart';
import '../../algo_interpreter/interpreter.dart';
import '../../algo_interpreter/debugger.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/ngenou_extension.dart';
import '../../core/providers/fichiers_provider.dart';
import '../../core/services/extensions_service.dart';
import '../../core/services/local_file_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/algo_code_editor.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final AlgoSyntaxController _controller = AlgoSyntaxController();
  final TextEditingController _outputController = TextEditingController();
  final GlobalKey<AlgoCodeEditorState> _editorKey =
      GlobalKey<AlgoCodeEditorState>();
  List<AlgoError> _errors = [];
  FileEvent? _lastFileEvent;
  bool _isRunning = false;
  bool _isInstallingExt = false;
  List<Map<String, dynamic>> _savedCodes = [];

  /// null = nouveau code non sauvegardé, sinon l'id en base.
  int? _currentProjectId;
  String? _currentProjectName;

  /// true si le code courant vient d'un exemple (pas encore sauvegardé sous un nom custom).
  bool _isExampleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCodes();
  }

  Future<void> _loadSavedCodes() async {
    final codes = await DatabaseHelper.instance.getCodesSauvegardes();
    setState(() => _savedCodes = codes);
  }

  Future<void> _downloadAndInstallExtension(NgenouExtension? ext) async {
    if (ext == null) return;
    setState(() => _isInstallingExt = true);
    final service = context.read<ExtensionsService>();
    final success = await service.installExtension(ext);
    if (mounted) {
      setState(() => _isInstallingExt = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Extension installée ! Bienvenue dans le terminal."),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Échec du téléchargement. Vérifiez votre connexion."),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  final Map<String, String> exemples = {
    "Hello World": '''Algorithme HelloWorld
Debut
   Ecrire("Bonjour le monde !");
Fin''',
    "Factorielle": '''Algorithme Factorielle
Var
   n, i, resultat : Entier;
Debut
   Ecrire("Entrez un entier positif : ");
   Lire(n);
   resultat ← 1;
   Pour i ← 1 a n Faire
      resultat ← resultat * i;
   FinPour
   Ecrire("Factorielle de ", n, " = ", resultat);
Fin''',
    "Tri à bulles": '''Algorithme TriBulles
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
         FinSi
      FinPour
   FinPour
   Pour i ← 1 a 5 Faire
      Ecrire(T[i]);
   FinPour
Fin''',
    "Recherche dichotomique": '''Algorithme RechercheDicho
Var
   T : Tableau[1..7] de Entier;
   cible, gauche, droite, milieu : Entier;
   trouve : Booléen;
Debut
   T[1] ← 1; T[2] ← 3; T[3] ← 5; T[4] ← 7; T[5] ← 9; T[6] ← 11; T[7] ← 13;
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
         FinSi
      FinSi
   FinTantQue
   Si (trouve) Alors
      Ecrire("Trouvé à l'indice ", milieu);
   Sinon
      Ecrire("Non trouvé");
   FinSi
Fin''',
    "Fonction (Carré & Somme)": '''Algorithme ExempleFonction
Fonction Carre(Entrée x : Entier) : Entier
Début
   Retourner(x * x);
FinFonction

Var
   n, res : Entier;
Début
   n ← 5;
   res ← Carre(n) + 1;
   Ecrire("Carre(", n, ") + 1 = ", res);
Fin''',
    "Procédure (Échange)": '''Algorithme ExempleProcedure
Procédure Echanger(Entrée/Sortie a : Entier, Entrée/Sortie b : Entier)
Variables
   tmp : Entier;
Début
   tmp ← a;
   a ← b;
   b ← tmp;
FinProcédure

Var
   x, y : Entier;
Début
   x ← 10;
   y ← 25;
   Echanger(x, y);
   Ecrire("x = ", x, ", y = ", y);
Fin''',
    "Fichiers (Clients)": '''Algorithme ExempleFichier
Type Structure Client
   Nom : Chaîne * 25;
   Prenom : Chaîne * 25;
FinStruct

Var
   clt : Client;
Début
   Ouvrir "clients.txt" en 1 en Ecriture;
   clt.Nom ← "Dupont";
   clt.Prenom ← "Jean";
   EcrireFichier 1, clt;
   Fermer(1);

   Ouvrir "clients.txt" en 1 en Lecture;
   TantQue Non EOF(1) Faire
      LireFichier 1, clt;
      Ecrire("Client : ", clt.Nom, " ", clt.Prenom);
   FinTantQue
   Fermer(1);
Fin''',
  };

  void _loadCodeString(
    String codeText, {
    int? projectId,
    String? projectName,
    bool isExample = false,
  }) {
    setState(() {
      _controller.text = codeText;
      _outputController.text = "";
      _errors = [];
      _lastFileEvent = null;
      _currentProjectId = projectId;
      _currentProjectName = projectName;
      _isExampleLoaded = isExample;
    });
  }

  void _runCode() async {
    final fichiersProvider = context.read<FichiersProvider>();
    fichiersProvider.updateLiveEvent(null);
    setState(() {
      _isRunning = true;
      _outputController.text = "";
      _errors = [];
      _lastFileEvent = null;
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
                    setDialogState(
                      () => errorText = 'La valeur ne peut pas être vide',
                    );
                    return false;
                  }
                  if (type == 'entier') {
                    if (int.tryParse(val) == null) {
                      setDialogState(
                        () => errorText = 'Veuillez saisir un entier valide',
                      );
                      return false;
                    }
                  } else if (type == 'réel' || type == 'reel') {
                    if (double.tryParse(val) == null) {
                      setDialogState(
                        () =>
                            errorText = 'Veuillez saisir un nombre réel valide',
                      );
                      return false;
                    }
                  } else if (type == 'booléen' || type == 'booleen') {
                    final lower = val.toLowerCase();
                    if (lower != 'vrai' &&
                        lower != 'faux' &&
                        lower != 'true' &&
                        lower != 'false') {
                      setDialogState(
                        () => errorText = 'Veuillez saisir vrai ou faux',
                      );
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
                    keyboardType:
                        (type == 'entier' || type == 'réel' || type == 'reel')
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
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
      fileStorage: LocalFileStorage(),
      onFileEvent: (ev) {
        fichiersProvider.updateLiveEvent(ev);
        if (mounted) {
          setState(() => _lastFileEvent = ev);
        }
      },
    );

    if (mounted) {
      fichiersProvider.loadFiles();
    }

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
                                _loadCodeString(exemples[k]!, isExample: true);
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
                                  _loadCodeString(
                                    s['code'] as String,
                                    projectId: s['id'] as int,
                                    projectName: s['nom'] as String,
                                  );
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
    final extService = context.watch<ExtensionsService>();
    final isExtInstalled = extService.isInstalled('algo_interpreter');

    if (!isExtInstalled) {
      final ext = extService.getExtensionById('algo_interpreter');
      return Scaffold(
        appBar: AppBar(title: const Text('Terminal Algo')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                color: isDark ? const Color(0xFF16161E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2ECC71,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(
                              0xFF2ECC71,
                            ).withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.terminal_rounded,
                          color: Color(0xFF2ECC71),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Extension requise",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "L'interpréteur de pseudo-code algorithmique doit être téléchargé pour exécuter, déboguer et tester vos programmes.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.75)
                              : Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.folder_zip_rounded,
                                      size: 18,
                                      color: Color(0xFF2ECC71),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Taille :",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ext?.taille ?? "48 Ko",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2ECC71),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Auteur :",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  ext?.auteur ?? "Yamga Daniel",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isInstallingExt
                              ? null
                              : () => _downloadAndInstallExtension(ext),
                          icon: _isInstallingExt
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(
                            _isInstallingExt
                                ? "Téléchargement en cours..."
                                : "Télécharger l'interpréteur (${ext?.taille ?? '48 Ko'})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Retour au cours"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideDesktop = screenWidth >= 960;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final int editorFlex = isKeyboardOpen ? 1 : (isTablet ? 6 : 5);
    final int outputFlex = isTablet ? 2 : 3;
    final accent = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.terminal_rounded, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            const Text(
              'Terminal Algo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (screenWidth >= 600) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_copy_rounded, size: 17),
                label: const Text('Fichiers'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.push('/fichiers'),
              ),
            ),
            const SizedBox(width: 6),
          ] else
            IconButton(
              icon: const Icon(Icons.folder_copy_rounded),
              tooltip: 'Gestionnaire de fichiers',
              onPressed: () => context.push('/fichiers'),
            ),
          IconButton(
            icon: const Icon(Icons.library_books_rounded),
            tooltip: 'Mes Scripts & Exemples',
            onPressed: _showScriptsModal,
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Sauvegarder (Ctrl+S)',
            onPressed: _saveWithCtrlS,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isWideDesktop ? 16.0 : 12.0),
          child: isWideDesktop && !isKeyboardOpen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildEditorPanel(isDark, accent, isDesktop: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          if (_lastFileEvent != null)
                            _buildLiveFileBandeau(isDark),
                          Expanded(child: _buildOutputPanel(isDark, accent)),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      flex: editorFlex,
                      child: _buildEditorPanel(
                        isDark,
                        accent,
                        isDesktop: false,
                      ),
                    ),
                    _buildActionBar(isDark, accent, isDesktop: false),
                    if (!isKeyboardOpen) ...[
                      if (_lastFileEvent != null) _buildLiveFileBandeau(isDark),
                      Expanded(
                        flex: outputFlex,
                        child: _buildOutputPanel(isDark, accent),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showSaveScriptDialog() async {
    if (_controller.text.trim().isEmpty) return;
    String nom = "";
    await showDialog(
      context: context,
      builder: (context) {
        final tCtrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Sauvegarder ce script"),
          content: TextField(
            controller: tCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Nom du script"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            FilledButton(
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
      final id = await DatabaseHelper.instance.insertCodeSauvegarde(
        nom.trim(),
        _controller.text,
      );
      setState(() {
        _currentProjectId = id;
        _currentProjectName = nom.trim();
        _isExampleLoaded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text("${nom.trim()} enregistré avec succès"),
          ),
        );
      }
      _loadSavedCodes();
    }
  }

  /// Ctrl+S : comportement intelligent selon l'état du code courant.
  Future<void> _saveWithCtrlS() async {
    if (_controller.text.trim().isEmpty) return;

    // Cas 1 : projet déjà sauvegardé → mise à jour silencieuse
    if (_currentProjectId != null && !_isExampleLoaded) {
      await DatabaseHelper.instance.updateCodeSauvegarde(
        _currentProjectId!,
        _controller.text,
      );
      await _loadSavedCodes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2ECC71),
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  "Enregistrement effectué avec succès",
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // Cas 2 : nouveau code non sauvegardé ou exemple → demander un nom
    await _showSaveScriptDialog();
  }

  Widget _buildEditorPanel(
    bool isDark,
    Color accent, {
    required bool isDesktop,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.08);
    final lineCount = _controller.text.isEmpty
        ? 1
        : '\n'.allMatches(_controller.text).length + 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.025),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.code_rounded, size: 17, color: accent),

                const SizedBox(width: 8),
                if (_currentProjectName != null) ...[
                  Text(
                    _currentProjectName!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, val, __) {
                    final lines = val.text.isEmpty
                        ? lineCount
                        : '\n'.allMatches(val.text).length + 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$lines ligne${lines > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _controller.clear();
                      _outputController.clear();
                      _errors = [];
                      _lastFileEvent = null;
                      _currentProjectId = null;
                      _currentProjectName = null;
                      _isExampleLoaded = false;
                    });
                  },
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  label: Text(
                    'Effacer',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: AlgoCodeEditor(
                key: _editorKey,
                controller: _controller,
                hintText: "Tapez votre algorithme ici...",
                onRun: _isRunning ? null : _runCode,
                onSave: _saveWithCtrlS,
              ),
            ),
          ),
          if (isDesktop)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
              ),
              child: _buildActionBar(isDark, accent, isDesktop: true),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isDark, Color accent, {required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 10.0,
        horizontal: isDesktop ? 12.0 : 0.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_rounded,
                    size: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Ctrl + Entrée',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
          FilledButton.icon(
            icon: _isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              _isRunning ? 'Exécution...' : 'Exécuter',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(136, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isRunning ? null : _runCode,
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel(bool isDark, Color accent) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.08);
    final hasErrors = _errors.isNotEmpty;
    final statusColor = _isRunning
        ? accent
        : (hasErrors ? AppColors.error : AppColors.success);
    final statusLabel = _isRunning
        ? 'En cours'
        : (hasErrors
              ? '${_errors.length} erreur${_errors.length > 1 ? 's' : ''}'
              : 'Prêt');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasErrors
              ? AppColors.error.withValues(alpha: 0.45)
              : borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.025),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 17,
                  color: hasErrors ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sortie Terminal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.clear_all_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  tooltip: 'Vider la console',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _outputController.clear();
                      _errors = [];
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF151519) : const Color(0xFFF6F7FA),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _outputController,
                        builder: (context, value, child) {
                          final isEmpty = value.text.isEmpty && _errors.isEmpty;
                          final textToShow = isEmpty
                              ? "Exécutez votre algorithme pour afficher le résultat ici..."
                              : "${value.text}${_errors.isNotEmpty ? '\n--- Erreurs ---\n${_errors.map((e) => e.toString()).join('\n')}' : ''}";

                          return SelectableText(
                            textToShow,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: isEmpty
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : (_errors.isNotEmpty
                                        ? (isDark
                                              ? Colors.red[300]
                                              : Colors.red[800])
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87)),
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_errors.any((e) => e.line > 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _errors
                            .where((e) => e.line > 0)
                            .map(
                              (e) => ActionChip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  Icons.my_location_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.red[200]
                                      : Colors.red[800],
                                ),
                                label: Text(
                                  'Aller à la ligne ${e.line}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.red[200]
                                        : Colors.red[800],
                                  ),
                                ),
                                backgroundColor: AppColors.error.withValues(
                                  alpha: 0.14,
                                ),
                                side: BorderSide(
                                  color: AppColors.error.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                onPressed: () =>
                                    _editorKey.currentState?.jumpToLine(e.line),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(FileOpenMode mode) {
    switch (mode) {
      case FileOpenMode.lecture:
        return 'Lecture';
      case FileOpenMode.ecriture:
        return 'Écriture';
      case FileOpenMode.ajout:
        return 'Ajout';
    }
  }

  Widget _buildLiveFileBandeau(bool isDark) {
    final ev = _lastFileEvent!;
    final accent = Theme.of(context).primaryColor;
    final isClosed = ev.type == FileEventType.close;
    final hasRecordHighlight =
        ev.record != null &&
        (ev.type == FileEventType.read || ev.type == FileEventType.write);
    final recordText = hasRecordHighlight
        ? (ev.record is Map ? jsonEncode(ev.record) : '${ev.record}')
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClosed
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.1))
              : accent.withValues(alpha: 0.55),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            isClosed ? Icons.lock_outline_rounded : Icons.sync_alt_rounded,
            size: 16,
            color: isClosed ? Colors.grey : accent,
          ),
          Text(
            'Canal ${ev.channel} · ${ev.fileName}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: (isClosed ? Colors.grey : accent).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isClosed ? 'Fermé' : _modeLabel(ev.mode),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isClosed ? Colors.grey : accent,
              ),
            ),
          ),
          Text(
            'Ligne ${ev.linePosition} / ${ev.totalLines}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          if (ev.isEof)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'EOF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          if (recordText != null)
            InkWell(
              onTap: () => context.push('/fichiers'),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(
                    alpha: isDark ? 0.22 : 0.16,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ev.type == FileEventType.write
                          ? Icons.edit_note_rounded
                          : Icons.visibility_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        '${ev.type == FileEventType.write ? 'Écrit' : 'Lu'} : $recordText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
