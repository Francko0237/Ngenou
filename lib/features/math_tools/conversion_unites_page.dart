import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConversionUnitesPage extends StatefulWidget {
  const ConversionUnitesPage({super.key});

  @override
  State<ConversionUnitesPage> createState() => _ConversionUnitesPageState();
}

class _ConversionUnitesPageState extends State<ConversionUnitesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mode 1 : Tableau de conversion
  String _selectedGrandeur = 'longueur'; // 'longueur', 'masse', 'capacite', 'aire'
  double _valeurInitiale = 3.45;
  late String _uniteDepart;
  late String _uniteCible;
  final TextEditingController _valeurController =
      TextEditingController(text: '3.45');

  // Mode 2 : Décomposition décimale
  double _nombreDecimal = 254.38;
  final TextEditingController _decimalInputController =
      TextEditingController(text: '254.38');

  // Mode 3 : Défis / Quiz
  late _ConversionQuiz _currentQuiz;
  String _quizReponseUtilisateur = '';
  bool? _quizEstCorrect;
  int _score = 0;
  int _totalQuestions = 0;

  final Map<String, _GrandeurConfig> _grandeurs = {
    'longueur': _GrandeurConfig(
      label: 'Longueurs',
      icon: Icons.straighten_rounded,
      uniteBase: 'm',
      unites: ['km', 'hm', 'dam', 'm', 'dm', 'cm', 'mm'],
      facteurs: [1000, 100, 10, 1, 0.1, 0.01, 0.001],
      colsParUnite: 1,
    ),
    'masse': _GrandeurConfig(
      label: 'Masses',
      icon: Icons.scale_rounded,
      uniteBase: 'g',
      unites: ['t', 'q', 'kg', 'hg', 'dag', 'g', 'dg', 'cg', 'mg'],
      facteurs: [1000000, 100000, 1000, 100, 10, 1, 0.1, 0.01, 0.001],
      colsParUnite: 1,
    ),
    'capacite': _GrandeurConfig(
      label: 'Capacités',
      icon: Icons.water_drop_rounded,
      uniteBase: 'L',
      unites: ['kL', 'hL', 'daL', 'L', 'dL', 'cL', 'mL'],
      facteurs: [1000, 100, 10, 1, 0.1, 0.01, 0.001],
      colsParUnite: 1,
    ),
    'aire': _GrandeurConfig(
      label: 'Aires (m²)',
      icon: Icons.crop_square_rounded,
      uniteBase: 'm²',
      unites: ['km²', 'hm² (ha)', 'dam² (a)', 'm²', 'dm²', 'cm²', 'mm²'],
      facteurs: [1000000, 10000, 100, 1, 0.01, 0.0001, 0.000001],
      colsParUnite: 2,
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _uniteDepart = _grandeurs[_selectedGrandeur]!.unites[3]; // 'm'
    _uniteCible = _grandeurs[_selectedGrandeur]!.unites[5]; // 'cm'
    _genererNouveauQuiz();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _valeurController.dispose();
    _decimalInputController.dispose();
    super.dispose();
  }

  void _onGrandeurChange(String g) {
    setState(() {
      _selectedGrandeur = g;
      final config = _grandeurs[g]!;
      _uniteDepart = config.unites[config.unites.length ~/ 2];
      _uniteCible = config.unites.last;
    });
  }

  void _genererNouveauQuiz() {
    final rand = math.Random();
    final grandeursKeys = ['longueur', 'masse', 'capacite'];
    final gKey = grandeursKeys[rand.nextInt(grandeursKeys.length)];
    final config = _grandeurs[gKey]!;

    final int idxDep = rand.nextInt(config.unites.length);
    int idxCib = rand.nextInt(config.unites.length);
    while (idxCib == idxDep) {
      idxCib = rand.nextInt(config.unites.length);
    }

    final double val = (rand.nextInt(900) + 10) / (rand.nextBool() ? 10 : 1);
    final double fDep = config.facteurs[idxDep];
    final double fCib = config.facteurs[idxCib];
    final double sol = (val * fDep) / fCib;

    setState(() {
      _currentQuiz = _ConversionQuiz(
        valeur: val,
        uniteDepart: config.unites[idxDep],
        uniteCible: config.unites[idxCib],
        solution: sol,
        grandeurLabel: config.label,
      );
      _quizReponseUtilisateur = '';
      _quizEstCorrect = null;
    });
  }

  void _verifierQuiz() {
    final rep = double.tryParse(_quizReponseUtilisateur.replaceAll(',', '.'));
    if (rep == null) return;

    final bool ok = (rep - _currentQuiz.solution).abs() < 0.0001;
    setState(() {
      _quizEstCorrect = ok;
      _totalQuestions++;
      if (ok) _score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF00B894);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E12) : const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text(
          'Tableau de Conversion & Décimaux',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_rounded), text: 'Tableau Interactif'),
            Tab(icon: Icon(Icons.pin_rounded), text: 'Rangs Décimaux'),
            Tab(icon: Icon(Icons.quiz_rounded), text: 'Défis & Entraînement'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTableauTab(isDark, accentColor),
          _buildRangsDecimauxTab(isDark, accentColor),
          _buildQuizTab(isDark, accentColor),
        ],
      ),
    );
  }

  // =========================================================================
  // ONGLET 1 : TABLEAU INTERACTIF DE CONVERSION
  // =========================================================================
  Widget _buildTableauTab(bool isDark, Color accentColor) {
    final config = _grandeurs[_selectedGrandeur]!;
    final int idxDep = config.unites.indexOf(_uniteDepart);
    final int idxCib = config.unites.indexOf(_uniteCible);

    final double facteurDep = idxDep >= 0 ? config.facteurs[idxDep] : 1.0;
    final double facteurCib = idxCib >= 0 ? config.facteurs[idxCib] : 1.0;
    final double resultat = (_valeurInitiale * facteurDep) / facteurCib;

    final int ecartRangs = (idxCib - idxDep) * config.colsParUnite;
    final String sensDeplacement = ecartRangs >= 0 ? 'droite' : 'gauche';
    final num facteurOperation = math.pow(10, ecartRangs.abs());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Choix de la grandeur
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _grandeurs.entries.map((entry) {
                    final isSelected = _selectedGrandeur == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(entry.value.icon, size: 16),
                        label: Text(entry.value.label),
                        selected: isSelected,
                        selectedColor: accentColor.withValues(alpha: 0.2),
                        onSelected: (_) => _onGrandeurChange(entry.key),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Zone de saisie + sélecteurs d'unités
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _valeurController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Valeur à convertir',
                              hintText: 'ex: 3.45',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) {
                              final d =
                                  double.tryParse(val.replaceAll(',', '.'));
                              if (d != null) {
                                setState(() => _valeurInitiale = d);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _uniteDepart,
                            decoration: InputDecoration(
                              labelText: 'De',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: config.unites.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (u) {
                              if (u != null) {
                                setState(() => _uniteDepart = u);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _uniteCible,
                            decoration: InputDecoration(
                              labelText: 'Vers',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: config.unites.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (u) {
                              if (u != null) {
                                setState(() => _uniteCible = u);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Rendu visuel du tableau dynamique avec les colonnes et chiffres
              _buildDynamicTableView(config, idxDep, idxCib, isDark, accentColor),

              const SizedBox(height: 18),

              // Résultat et règle pédagogique pas-à-pas
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.14),
                      accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_valeurInitiale $_uniteDepart',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.swap_horiz_rounded, size: 24),
                        Text(
                          '${_formatResultat(resultat)} $_uniteCible',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ecartRangs == 0
                                ? 'Les deux unités sont identiques.'
                                : 'Pour passer de $_uniteDepart à $_uniteCible, on décale la virgule de ${ecartRangs.abs()} rang(s) vers la $sensDeplacement (on ${ecartRangs >= 0 ? "multiplie par" : "divise par"} $facteurOperation).',
                            style: const TextStyle(fontSize: 13.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicTableView(
    _GrandeurConfig config,
    int idxDep,
    int idxCib,
    bool isDark,
    Color accentColor,
  ) {
    final Map<int, String> digitsPlacement = _computeDigitsInTable(config, idxDep, idxCib);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(64),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
              verticalInside: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
            ),
            children: [
              // Ligne 1 : En-têtes d'unités
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F3F6),
                ),
                children: config.unites.asMap().entries.map((e) {
                  final int idx = e.key;
                  final String unitName = e.value;
                  final bool isDep = idx == idxDep;
                  final bool isCib = idx == idxCib;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    color: isCib
                        ? accentColor.withValues(alpha: 0.22)
                        : (isDep ? Colors.amber.withValues(alpha: 0.22) : null),
                    child: Column(
                      children: [
                        Text(
                          unitName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCib
                                ? accentColor
                                : (isDep ? Colors.amber.shade700 : null),
                          ),
                        ),
                        if (isDep)
                          const Text('Départ',
                              style: TextStyle(
                                  fontSize: 9.5, color: Colors.amber)),
                        if (isCib && !isDep)
                          Text('Arrivée',
                              style: TextStyle(
                                  fontSize: 9.5, color: accentColor)),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // Ligne 2 : Chiffres positionnés
              TableRow(
                children: List.generate(config.unites.length, (colIdx) {
                  final String digit = digitsPlacement[colIdx] ?? '';
                  final bool hasDigit = digit.isNotEmpty;
                  // La virgule du RÉSULTAT se place après la colonne cible
                  final bool isCommaHere = colIdx == idxCib;
                  // Distinguer visuellement les zéros de remplissage
                  final bool isFillerZero = hasDigit && digit == '0';

                  return Container(
                    height: 54,
                    alignment: Alignment.center,
                    color: (colIdx >= (idxDep < idxCib ? idxDep : idxCib) &&
                            colIdx <= (idxDep > idxCib ? idxDep : idxCib))
                        ? accentColor.withValues(alpha: 0.05)
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          hasDigit ? digit : '',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: !hasDigit
                                ? Colors.transparent
                                : isFillerZero
                                    ? (isDark
                                        ? Colors.white38
                                        : Colors.black38)
                                    : (isDark
                                        ? Colors.white
                                        : Colors.black87),
                          ),
                        ),
                        if (isCommaHere)
                          Positioned(
                            right: 2,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                ',',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<int, String> _computeDigitsInTable(
    _GrandeurConfig config,
    int idxDep,
    int idxCib,
  ) {
    final Map<int, String> map = {};
    if (idxDep < 0) return map;

    // Convertir la valeur en chaîne sans notation scientifique
    String valStr = _valeurInitiale.toStringAsFixed(10)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    final parts = valStr.split('.');
    final String intPart = parts[0].replaceAll('-', '');
    final String decPart = parts.length > 1 ? parts[1] : '';

    // La virgule d'origine est APRÈS la colonne de l'unité de départ (idxDep)
    // Placer la partie entière vers la GAUCHE depuis idxDep
    for (int i = 0; i < intPart.length; i++) {
      final int col = idxDep - (intPart.length - 1 - i);
      if (col >= 0 && col < config.unites.length) {
        map[col] = intPart[i];
      }
    }

    // Placer la partie décimale vers la DROITE depuis idxDep + 1
    for (int i = 0; i < decPart.length; i++) {
      final int col = idxDep + 1 + i;
      if (col >= 0 && col < config.unites.length) {
        map[col] = decPart[i];
      }
    }

    // Déterminer la plage à remplir :
    // Du premier chiffre significatif jusqu'à la colonne cible (au minimum)
    final int firstFilledCol = map.keys.isEmpty ? idxDep : map.keys.reduce((a, b) => a < b ? a : b);
    final int lastFilledCol = map.keys.isEmpty ? idxDep : map.keys.reduce((a, b) => a > b ? a : b);
    final int rangeStart = firstFilledCol;
    final int rangeEnd = idxCib > lastFilledCol ? idxCib : lastFilledCol;

    // Remplir TOUTES les cases dans la plage avec '0' si vides
    for (int col = rangeStart; col <= rangeEnd; col++) {
      if (col >= 0 && col < config.unites.length && !map.containsKey(col)) {
        map[col] = '0';
      }
    }

    return map;
  }

  // =========================================================================
  // ONGLET 2 : RANGS DÉCIMAUX & DÉCOMPOSITION
  // =========================================================================
  Widget _buildRangsDecimauxTab(bool isDark, Color accentColor) {
    final parts = _nombreDecimal.toString().split('.');
    final String intPart = parts[0];
    final String decPart = parts.length > 1 ? parts[1] : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Champ de saisie
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: TextField(
                  controller: _decimalInputController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Entrez un nombre décimal',
                    hintText: 'ex: 254.38',
                    prefixIcon: const Icon(Icons.pin_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val.replaceAll(',', '.'));
                    if (d != null) {
                      setState(() => _nombreDecimal = d);
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Tableau des rangs : Centaines, Dizaines, Unités | Dixièmes, Centièmes, Millièmes
              _buildRangsTable(intPart, decPart, isDark, accentColor),

              const SizedBox(height: 20),

              // Décomposition mathématique détaillée (6ème / 5ème)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.functions_rounded, color: Color(0xFF0984E3)),
                        SizedBox(width: 8),
                        Text(
                          'Décomposition canonique',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _buildDecompositionText(intPart, decPart),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14.5,
                        height: 1.6,
                        color: Color(0xFF0984E3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      '• Partie entière : $intPart unités\n'
                      '• Partie décimale : 0,$decPart (${decPart.length == 1 ? "$decPart dixièmes" : "$decPart centièmes"})',
                      style: const TextStyle(fontSize: 13.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangsTable(
    String intPart,
    String decPart,
    bool isDark,
    Color accentColor,
  ) {
    const headersEntiers = ['Milliers', 'Centaines', 'Dizaines', 'Unités'];
    const headersDecimaux = ['Dixièmes (1/10)', 'Centièmes (1/100)', 'Millièmes (1/1000)'];

    // 4 colonnes entières, 3 colonnes décimales
    final Map<int, String> colValues = {};
    for (int i = 0; i < intPart.length && i < 4; i++) {
      final int digitIdx = intPart.length - 1 - i;
      colValues[3 - i] = intPart[digitIdx];
    }
    for (int i = 0; i < decPart.length && i < 3; i++) {
      colValues[4 + i] = decPart[i];
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(76),
            border: TableBorder(
              horizontalInside: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12, width: 1),
              verticalInside: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12, width: 1),
            ),
            children: [
              // En-tête Partie Entière vs Partie Décimale
              TableRow(
                children: [
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0xFF0984E3).withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      child: const Text('Partie Entière (4 rangs)',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  ...List.generate(
                    3,
                    (_) => TableCell(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFF0984E3).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: accentColor.withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      child: const Text('Partie Décimale',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  ...List.generate(
                    2,
                    (_) => TableCell(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),

              // Rangs individuels
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F3F6),
                ),
                children: [
                  ...headersEntiers.map((h) => _headerCell(h, false)),
                  ...headersDecimaux.map((h) => _headerCell(h, true)),
                ],
              ),

              // Chiffres
              TableRow(
                children: List.generate(7, (idx) {
                  final digit = colValues[idx] ?? '';
                  final isVirguleAfter = idx == 3;

                  return Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          digit.isNotEmpty ? digit : '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: digit.isNotEmpty
                                ? (idx < 4
                                    ? const Color(0xFF0984E3)
                                    : accentColor)
                                : Colors.grey.shade400,
                          ),
                        ),
                        if (isVirguleAfter)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              ',',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String label, bool isDecimal) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDecimal ? const Color(0xFF00B894) : const Color(0xFF0984E3),
        ),
      ),
    );
  }

  String _buildDecompositionText(String intPart, String decPart) {
    final List<String> morceaux = [];

    // Partie entière
    for (int i = 0; i < intPart.length; i++) {
      final ch = intPart[i];
      if (ch != '0') {
        final puissance = intPart.length - 1 - i;
        final facteur = math.pow(10, puissance);
        morceaux.add('($ch × $facteur)');
      }
    }

    // Partie décimale
    for (int i = 0; i < decPart.length; i++) {
      final ch = decPart[i];
      if (ch != '0') {
        final denom = math.pow(10, i + 1);
        morceaux.add('($ch / $denom)');
      }
    }

    return morceaux.join(' + ');
  }

  // =========================================================================
  // ONGLET 3 : DÉFIS & ENTRAÎNEMENT (QUIZ)
  // =========================================================================
  Widget _buildQuizTab(bool isDark, Color accentColor) {
    final q = _currentQuiz;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score : $_score / $_totalQuestions',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: _genererNouveauQuiz,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Passer / Suivant'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Carte de question
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        q.grandeurLabel,
                        style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Convertis ${q.valeur} ${q.uniteDepart} en ${q.uniteCible} :',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Résultat',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) {
                              _quizReponseUtilisateur = val;
                            },
                            onSubmitted: (_) => _verifierQuiz(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          q.uniteCible,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _verifierQuiz,
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Valider ma réponse',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              if (_quizEstCorrect != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _quizEstCorrect!
                        ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                        : const Color(0xFFE74C3C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _quizEstCorrect!
                          ? const Color(0xFF2ECC71)
                          : const Color(0xFFE74C3C),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _quizEstCorrect!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _quizEstCorrect!
                            ? const Color(0xFF2ECC71)
                            : const Color(0xFFE74C3C),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _quizEstCorrect!
                                  ? 'Bravo, c\'est exact !'
                                  : 'Oups, ce n\'est pas tout à fait ça.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _quizEstCorrect!
                                    ? const Color(0xFF2ECC71)
                                    : const Color(0xFFE74C3C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Réponse attendue : ${_formatResultat(q.solution)} ${q.uniteCible}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatResultat(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    // Évite l'écriture exponentielle inutile
    return val.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}

class _GrandeurConfig {
  final String label;
  final IconData icon;
  final String uniteBase;
  final List<String> unites;
  final List<double> facteurs;
  final int colsParUnite;

  _GrandeurConfig({
    required this.label,
    required this.icon,
    required this.uniteBase,
    required this.unites,
    required this.facteurs,
    required this.colsParUnite,
  });
}

class _ConversionQuiz {
  final double valeur;
  final String uniteDepart;
  final String uniteCible;
  final double solution;
  final String grandeurLabel;

  _ConversionQuiz({
    required this.valeur,
    required this.uniteDepart,
    required this.uniteCible,
    required this.solution,
    required this.grandeurLabel,
  });
}
