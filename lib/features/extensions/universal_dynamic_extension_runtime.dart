import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/ngenou_extension.dart';
import '../terminal/terminal_page.dart';

/// Moteur universel d'exécution déclarative d'extensions Ngenou.
/// Ce moteur est 100% agnostique : il ne contient AUCUNE référence en dur à une extension.
/// Il lit dynamiquement le schéma `bundle.json` téléchargé depuis GitHub et construit
/// l'interface réactive, les contrôles et les composants visuels.
class UniversalDynamicExtensionRuntime extends StatefulWidget {
  final Map<String, dynamic> bundleData;
  final NgenouExtension extension;

  const UniversalDynamicExtensionRuntime({
    super.key,
    required this.bundleData,
    required this.extension,
  });

  @override
  State<UniversalDynamicExtensionRuntime> createState() =>
      _UniversalDynamicExtensionRuntimeState();
}

class _UniversalDynamicExtensionRuntimeState
    extends State<UniversalDynamicExtensionRuntime>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _state;
  TabController? _tabController;
  List<Map<String, dynamic>> _tabs = [];

  @override
  void initState() {
    super.initState();
    _initStateAndTabs();
  }

  void _initStateAndTabs() {
    final rawState = widget.bundleData['initialState'] as Map<String, dynamic>?;
    _state = rawState != null ? Map<String, dynamic>.from(rawState) : {};

    final rawTabs = widget.bundleData['tabs'] as List<dynamic>?;
    if (rawTabs != null && rawTabs.isNotEmpty) {
      _tabs = rawTabs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
  }

  @override
  void didUpdateWidget(UniversalDynamicExtensionRuntime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundleData != widget.bundleData) {
      _tabController?.dispose();
      _initStateAndTabs();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _updateState(String key, dynamic value) {
    setState(() {
      _state[key] = value;
    });
  }

  bool _isBlockVisible(Map<String, dynamic> block) {
    final cond = block['visibleWhen'] as Map<String, dynamic>?;
    if (cond == null) return true;
    final key = cond['key'] as String?;
    final equals = cond['equals'];
    if (key == null) return true;
    return _state[key] == equals;
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'linear_scale':
      case 'timeline':
        return Icons.linear_scale_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'pie_chart':
      case 'circle':
        return Icons.pie_chart_rounded;
      case 'compare_arrows':
        return Icons.compare_arrows_rounded;
      case 'terminal':
      case 'code':
        return Icons.terminal_rounded;
      case 'view_week':
        return Icons.view_week_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentHex = widget.bundleData['accentColor'] as String? ?? '#3498DB';
    final accentColor = _parseColor(accentHex, const Color(0xFF3498DB));
    final title = widget.bundleData['title'] as String? ?? widget.extension.nom;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E12) : const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: _tabs.isNotEmpty && _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: _tabs.length > 3,
                labelColor: accentColor,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                indicatorColor: accentColor,
                indicatorWeight: 3,
                tabs: _tabs.map((tab) {
                  final label = tab['title'] as String? ?? 'Onglet';
                  final iconName = tab['icon'] as String?;
                  return Tab(
                    icon: Icon(_parseIcon(iconName)),
                    text: label,
                  );
                }).toList(),
              )
            : null,
      ),
      body: _tabs.isNotEmpty && _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((tab) => _buildTabContent(tab, isDark, accentColor))
                  .toList(),
            )
          : _buildSingleView(widget.bundleData, isDark, accentColor),
    );
  }

  Widget _buildSingleView(
    Map<String, dynamic> data,
    bool isDark,
    Color accentColor,
  ) {
    final blocks = (data['blocks'] as List<dynamic>?) ?? [];
    return _buildBlockList(blocks, isDark, accentColor);
  }

  Widget _buildTabContent(
    Map<String, dynamic> tabData,
    bool isDark,
    Color accentColor,
  ) {
    final blocks = (tabData['blocks'] as List<dynamic>?) ?? [];
    return _buildBlockList(blocks, isDark, accentColor);
  }

  Widget _buildBlockList(
    List<dynamic> blocks,
    bool isDark,
    Color accentColor,
  ) {
    final visibleBlocks = blocks
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where(_isBlockVisible)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: visibleBlocks.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildBlock(b, isDark, accentColor),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final type = block['type'] as String? ?? 'unknown';

    switch (type) {
      case 'segmented':
        return _buildSegmentedBlock(block, accentColor);

      case 'slider':
        return _buildSliderBlock(block, isDark, accentColor);

      case 'stepper':
        return _buildStepperBlock(block, isDark, accentColor);

      case 'button_group':
        return _buildButtonGroupBlock(block, accentColor);

      case 'number_line':
        return _buildNumberLineBlock(block, isDark, accentColor);

      case 'number_line_vector':
        return _buildNumberLineVectorBlock(block, isDark, accentColor);

      case 'thermometer':
        return _buildThermometerBlock(block, isDark, accentColor);

      case 'fraction_shape':
        return _buildFractionShapeBlock(block, isDark, accentColor);

      case 'fraction_compare_view':
        return _buildFractionCompareBlock(block, isDark, accentColor);

      case 'fraction_stats_card':
        return _buildFractionStatsBlock(block, isDark, accentColor);

      case 'relatifs_comparison_card':
        return _buildRelatifsComparisonCard(block, isDark, accentColor);

      case 'relatifs_operation_card':
        return _buildRelatifsOperationCard(block, isDark, accentColor);

      case 'algo_console_runner':
        return _buildAlgoConsoleRunner(block, isDark, accentColor);

      case 'card':
        return _buildCardBlock(block, isDark, accentColor);

      default:
        return const SizedBox.shrink();
    }
  }

  // --- COMPOSANT 1 : SÉLECTEUR SEGMENTÉ ---
  Widget _buildSegmentedBlock(Map<String, dynamic> block, Color accentColor) {
    final stateKey = block['stateKey'] as String? ?? '';
    final options = (block['options'] as List<dynamic>?) ?? [];
    final currentVal = _state[stateKey];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((opt) {
        final optMap = opt as Map<String, dynamic>;
        final val = optMap['value'];
        final label = optMap['label'] as String? ?? '';
        final iconName = optMap['icon'] as String?;
        final isSelected = currentVal == val;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconName != null) ...[
                  Icon(_parseIcon(iconName), size: 16),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
            selected: isSelected,
            selectedColor: accentColor.withValues(alpha: 0.18),
            onSelected: (_) => _updateState(stateKey, val),
          ),
        );
      }).toList(),
    );
  }

  // --- COMPOSANT 2 : SLIDER INTERACTIF ---
  Widget _buildSliderBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final stateKey = block['stateKey'] as String? ?? '';
    final label = block['label'] as String? ?? stateKey;
    final min = (block['min'] as num?)?.toDouble() ?? -10.0;
    final max = (block['max'] as num?)?.toDouble() ?? 10.0;
    final colorHex = block['color'] as String?;
    final col = _parseColor(colorHex, accentColor);
    final rawVal = _state[stateKey];
    final num val = (rawVal is num) ? rawVal : min;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  val >= 0 ? '+$val' : '$val',
                  style: TextStyle(
                    color: col,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: val.toDouble().clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: col,
            onChanged: (newVal) => _updateState(stateKey, newVal.round()),
          ),
        ],
      ),
    );
  }

  // --- COMPOSANT 3 : STEPPER CONTROLS (+ / -) ---
  Widget _buildStepperBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final stateKey = block['stateKey'] as String? ?? '';
    final label = block['label'] as String? ?? stateKey;
    final min = (block['min'] as num?)?.toInt() ?? 0;
    final max = (block['max'] as num?)?.toInt() ?? 20;
    final rawVal = _state[stateKey];
    final int val = (rawVal is num) ? rawVal.toInt() : min;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: val > min ? accentColor : Colors.grey,
                onPressed:
                    val > min ? () => _updateState(stateKey, val - 1) : null,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$val',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: val < max ? accentColor : Colors.grey,
                onPressed:
                    val < max ? () => _updateState(stateKey, val + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- COMPOSANT 4 : BUTTON GROUP ---
  Widget _buildButtonGroupBlock(
    Map<String, dynamic> block,
    Color accentColor,
  ) {
    final stateKey = block['stateKey'] as String? ?? '';
    final label = block['label'] as String? ?? '';
    final options = (block['options'] as List<dynamic>?) ?? ['+', '-'];
    final currentVal = _state[stateKey] ?? options.first;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (label.isNotEmpty) ...[
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
        ],
        ...options.map((opt) {
          final isSelected = currentVal == opt;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FilterChip(
              label: Text(
                '$opt',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? accentColor : null,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _updateState(stateKey, opt),
            ),
          );
        }),
      ],
    );
  }

  // --- COMPOSANT 5 : DROITE GRADUÉE INTERACTIVE ---
  Widget _buildNumberLineBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final min = (block['min'] as num?)?.toInt() ?? -10;
    final max = (block['max'] as num?)?.toInt() ?? 10;
    final pointsConfig = (block['points'] as List<dynamic>?) ?? [];

    final points = <_PointMark>[];
    for (final p in pointsConfig) {
      final pMap = p as Map<String, dynamic>;
      final name = pMap['name'] as String? ?? '';
      final stateKey = pMap['stateKey'] as String? ?? '';
      final colorHex = pMap['color'] as String?;
      final color = _parseColor(colorHex, accentColor);
      final rawVal = _state[stateKey];
      final int? val = (rawVal is num) ? rawVal.toInt() : null;
      if (val != null) {
        points.add(_PointMark(name: name, value: val, color: color));
      }
    }

    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: CustomPaint(
        painter: _UniversalDroitePainter(
          minVal: min,
          maxVal: max,
          points: points,
          isDark: isDark,
        ),
      ),
    );
  }

  // --- COMPOSANT 6 : VECTEUR ARITHMÉTIQUE SUR L'AXE ---
  Widget _buildNumberLineVectorBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final min = (block['min'] as num?)?.toInt() ?? -10;
    final max = (block['max'] as num?)?.toInt() ?? 10;
    final startKey = block['startKey'] as String? ?? '';
    final secondKey = block['secondKey'] as String? ?? '';
    final operatorKey = block['operatorKey'] as String? ?? '';

    final int startVal = (_state[startKey] as num?)?.toInt() ?? -2;
    final int secondVal = (_state[secondKey] as num?)?.toInt() ?? 5;
    final String op = _state[operatorKey] as String? ?? '+';
    final int endVal = op == '+' ? (startVal + secondVal) : (startVal - secondVal);

    return Container(
      width: double.infinity,
      height: 170,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: CustomPaint(
        painter: _UniversalVectorDroitePainter(
          minVal: min,
          maxVal: max,
          startVal: startVal,
          endVal: endVal,
          isDark: isDark,
          accentColor: accentColor,
        ),
      ),
    );
  }

  // --- COMPOSANT 7 : THERMOMÈTRE DYNAMIQUE ---
  Widget _buildThermometerBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final min = (block['min'] as num?)?.toInt() ?? -10;
    final max = (block['max'] as num?)?.toInt() ?? 10;
    final pointsConfig = (block['points'] as List<dynamic>?) ?? [];

    final points = <_PointMark>[];
    for (final p in pointsConfig) {
      final pMap = p as Map<String, dynamic>;
      final name = pMap['name'] as String? ?? '';
      final stateKey = pMap['stateKey'] as String? ?? '';
      final colorHex = pMap['color'] as String?;
      final color = _parseColor(colorHex, accentColor);
      final rawVal = _state[stateKey];
      final int? val = (rawVal is num) ? rawVal.toInt() : null;
      if (val != null) {
        points.add(_PointMark(name: name, value: val, color: color));
      }
    }

    return Container(
      width: double.infinity,
      height: 280,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: CustomPaint(
        painter: _UniversalThermometerPainter(
          minVal: min,
          maxVal: max,
          points: points,
          isDark: isDark,
        ),
      ),
    );
  }

  // --- COMPOSANT 8 : FRACTIONS EN DISQUE OU BARRE ---
  Widget _buildFractionShapeBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final numKey = block['numKey'] as String? ?? 'num1';
    final denKey = block['denKey'] as String? ?? 'den1';
    final shapeKey = block['shapeKey'] as String? ?? 'shape';
    final colorHex = block['color'] as String?;
    final col = _parseColor(colorHex, accentColor);

    final int numVal = (_state[numKey] as num?)?.toInt() ?? 3;
    final int denVal = math.max(1, (_state[denKey] as num?)?.toInt() ?? 4);
    final String shape = _state[shapeKey] as String? ?? 'disk';

    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(200, 180),
          painter: _UniversalFractionPainter(
            numerator: numVal,
            denominator: denVal,
            isDisk: shape == 'disk',
            color: col,
            isDark: isDark,
          ),
        ),
      ),
    );
  }

  // --- COMPOSANT 9 : COMPARATEUR DE FRACTIONS ---
  Widget _buildFractionCompareBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final num1Key = block['num1Key'] as String? ?? 'num1';
    final den1Key = block['den1Key'] as String? ?? 'den1';
    final num2Key = block['num2Key'] as String? ?? 'num2';
    final den2Key = block['den2Key'] as String? ?? 'den2';
    final shapeKey = block['shapeKey'] as String? ?? 'shape';

    final int n1 = (_state[num1Key] as num?)?.toInt() ?? 3;
    final int d1 = math.max(1, (_state[den1Key] as num?)?.toInt() ?? 4);
    final int n2 = (_state[num2Key] as num?)?.toInt() ?? 1;
    final int d2 = math.max(1, (_state[den2Key] as num?)?.toInt() ?? 2);
    final String shape = _state[shapeKey] as String? ?? 'disk';

    final double val1 = n1 / d1;
    final double val2 = n2 / d2;
    String symbol = '=';
    if (val1 > val2) symbol = '>';
    if (val1 < val2) symbol = '<';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomPaint(
                size: const Size(110, 110),
                painter: _UniversalFractionPainter(
                  numerator: n1,
                  denominator: d1,
                  isDisk: shape == 'disk',
                  color: const Color(0xFFE67E22),
                  isDark: isDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(110, 110),
                painter: _UniversalFractionPainter(
                  numerator: n2,
                  denominator: d2,
                  isDisk: shape == 'disk',
                  color: const Color(0xFF2ECC71),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$n1/$d1 $symbol $n2/$d2',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // --- COMPOSANT 10 : STATS FRACTION ---
  Widget _buildFractionStatsBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final numKey = block['numKey'] as String? ?? 'num1';
    final denKey = block['denKey'] as String? ?? 'den1';

    final int n = (_state[numKey] as num?)?.toInt() ?? 3;
    final int d = math.max(1, (_state[denKey] as num?)?.toInt() ?? 4);

    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final int g = gcd(n, d);
    final int simpN = n ~/ g;
    final int simpD = d ~/ g;
    final double decVal = n / d;
    final double pct = decVal * 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Forme irréductible', '$simpN/$simpD', accentColor),
          _statItem('Décimal', decVal.toStringAsFixed(2), accentColor),
          _statItem('Pourcentage', '${pct.toStringAsFixed(1)} %', accentColor),
        ],
      ),
    );
  }

  Widget _statItem(String title, String val, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 17, color: color)),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
      ],
    );
  }

  // --- COMPOSANT 11 : CARTE RÈGLE RELATIFS ---
  Widget _buildRelatifsComparisonCard(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final keyA = block['keyA'] as String? ?? 'pointA';
    final keyB = block['keyB'] as String? ?? 'pointB';

    final int valA = (_state[keyA] as num?)?.toInt() ?? -3;
    final int valB = (_state[keyB] as num?)?.toInt() ?? 4;
    final int distA = valA.abs();
    final int distB = valB.abs();
    final bool sontEgaux = valA == valB;
    final bool aSuperieur = valA > valB;

    String explication;
    if (sontEgaux) {
      explication = 'Les deux points sont au même repère ($valA).';
    } else if (valA >= 0 && valB < 0) {
      explication =
          'Tout nombre positif ($valA) est supérieur à tout nombre négatif ($valB).';
    } else if (valA < 0 && valB >= 0) {
      explication =
          'Tout nombre négatif ($valA) est inférieur à tout nombre positif ($valB).';
    } else if (valA >= 0 && valB >= 0) {
      explication =
          'Entre deux positifs, le plus grand a la plus grande distance à zéro ($distA > $distB).';
    } else {
      explication =
          'Entre deux négatifs, le plus grand a la PLUS PETITE distance à zéro (le plus proche de 0 : $distA ${aSuperieur ? '<' : '>'} $distB).';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Règle mathématique appliquée',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explication,
            style: const TextStyle(height: 1.45, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  // --- COMPOSANT 12 : CARTE OPÉRATION RELATIFS ---
  Widget _buildRelatifsOperationCard(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final term1Key = block['term1Key'] as String? ?? 'opTerm1';
    final term2Key = block['term2Key'] as String? ?? 'opTerm2';
    final opKey = block['opKey'] as String? ?? 'operateur';

    final int t1 = (_state[term1Key] as num?)?.toInt() ?? -2;
    final int t2 = (_state[term2Key] as num?)?.toInt() ?? 5;
    final String op = _state[opKey] as String? ?? '+';
    final int res = op == '+' ? (t1 + t2) : (t1 - t2);

    String detail;
    if (op == '+') {
      if ((t1 >= 0 && t2 >= 0) || (t1 <= 0 && t2 <= 0)) {
        detail =
            'Même signe : on garde le signe commun et on additionne les distances (${t1.abs()} + ${t2.abs()} = ${res.abs()}).';
      } else {
        detail =
            'Signes différents : le résultat prend le signe de la plus grande distance à zéro.';
      }
    } else {
      detail =
          'Règle d\'or : Soustraire revient à ajouter l\'opposé !\n($t1) - ($t2) = ($t1) + (${-t2}) = $res';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('($t1) $op ($t2)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '= $res',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail,
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey, height: 1.4)),
        ],
      ),
    );
  }

  // --- COMPOSANT 13 : EXÉCUTEUR CONSOLE ALGO (TERMINAL COMPLET) ---
  Widget _buildAlgoConsoleRunner(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    return const SizedBox(
      height: 620,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        child: TerminalPage(),
      ),
    );
  }

  // --- COMPOSANT 14 : CARTE DE TEXTE / INFO GÉNÉRIQUE ---
  Widget _buildCardBlock(
    Map<String, dynamic> block,
    bool isDark,
    Color accentColor,
  ) {
    final title = block['title'] as String? ?? '';
    final content = block['content'] as String? ?? '';

    // Interpolation des variables {nomVar}
    String processed = content;
    _state.forEach((k, v) {
      processed = processed.replaceAll('{$k}', '$v');
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
          ],
          Text(processed,
              style: const TextStyle(fontSize: 13.5, height: 1.45)),
        ],
      ),
    );
  }
}

class _PointMark {
  final String name;
  final int value;
  final Color color;

  _PointMark({required this.name, required this.value, required this.color});
}

// --- PAINTER DROITE GRADUÉE ---
class _UniversalDroitePainter extends CustomPainter {
  final int minVal;
  final int maxVal;
  final List<_PointMark> points;
  final bool isDark;

  _UniversalDroitePainter({
    required this.minVal,
    required this.maxVal,
    required this.points,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double yCenter = size.height / 2;
    final double totalUnits = (maxVal - minVal).toDouble();
    final double unitWidth = (size.width - 40) / totalUnits;
    const double startX = 20.0;

    double xFromVal(num v) => startX + (v - minVal) * unitWidth;

    final axisPaint = Paint()
      ..color = isDark ? Colors.white60 : Colors.black87
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(startX, yCenter), Offset(size.width - 15, yCenter), axisPaint);

    final arrowPaint = Paint()
      ..color = axisPaint.color
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(size.width - 10, yCenter)
      ..lineTo(size.width - 20, yCenter - 5)
      ..lineTo(size.width - 20, yCenter + 5)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    final tickPaint = Paint()
      ..color = isDark ? Colors.white38 : Colors.black45
      ..strokeWidth = 1.2;

    for (int i = minVal; i <= maxVal; i++) {
      final double x = xFromVal(i);
      final bool isOrigin = i == 0;
      final double tickH = isOrigin ? 12 : 6;

      canvas.drawLine(
          Offset(x, yCenter - tickH), Offset(x, yCenter + tickH), tickPaint);

      if (i % 2 == 0 || isOrigin) {
        final tp = TextPainter(
          text: TextSpan(
            text: isOrigin ? '0' : (i > 0 ? '+$i' : '$i'),
            style: TextStyle(
              color: isOrigin
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white54 : Colors.black54),
              fontSize: 10,
              fontWeight: isOrigin ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, yCenter + 14));
      }
    }

    for (final p in points) {
      final double px = xFromVal(p.value);
      final circlePaint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, yCenter), 6, circlePaint);
      canvas.drawCircle(
        Offset(px, yCenter),
        6,
        Paint()
          ..color = isDark ? Colors.black : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${p.name} (${p.value >= 0 ? "+${p.value}" : p.value})',
          style: TextStyle(
            color: p.color,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, yCenter - 26));
    }
  }

  @override
  bool shouldRepaint(covariant _UniversalDroitePainter oldDelegate) => true;
}

// --- PAINTER VECTEUR ARITHMÉTIQUE ---
class _UniversalVectorDroitePainter extends CustomPainter {
  final int minVal;
  final int maxVal;
  final int startVal;
  final int endVal;
  final bool isDark;
  final Color accentColor;

  _UniversalVectorDroitePainter({
    required this.minVal,
    required this.maxVal,
    required this.startVal,
    required this.endVal,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double yCenter = size.height / 2 + 10;
    final double totalUnits = (maxVal - minVal).toDouble();
    final double unitWidth = (size.width - 40) / totalUnits;
    const double startX = 20.0;

    double xFromVal(num v) => startX + (v - minVal) * unitWidth;

    final axisPaint = Paint()
      ..color = isDark ? Colors.white60 : Colors.black87
      ..strokeWidth = 2.0;
    canvas.drawLine(
        Offset(startX, yCenter), Offset(size.width - 15, yCenter), axisPaint);

    final double xStart = xFromVal(startVal);
    final double xEnd = xFromVal(endVal);

    // Flèche de vecteur au-dessus
    final double yArc = yCenter - 34;
    final vectorPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(xStart, yCenter - 8)
      ..quadraticBezierTo((xStart + xEnd) / 2, yArc, xEnd, yCenter - 8);
    canvas.drawPath(path, vectorPaint);

    // Marqueurs
    canvas.drawCircle(
        Offset(xStart, yCenter), 5, Paint()..color = const Color(0xFFE67E22));
    canvas.drawCircle(
        Offset(xEnd, yCenter), 6, Paint()..color = const Color(0xFF2ECC71));
  }

  @override
  bool shouldRepaint(covariant _UniversalVectorDroitePainter oldDelegate) => true;
}

// --- PAINTER THERMOMÈTRE ---
class _UniversalThermometerPainter extends CustomPainter {
  final int minVal;
  final int maxVal;
  final List<_PointMark> points;
  final bool isDark;

  _UniversalThermometerPainter({
    required this.minVal,
    required this.maxVal,
    required this.points,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    const double top = 20;
    final double bottom = size.height - 30;
    final double height = bottom - top;

    double yFromTemp(num t) =>
        bottom - ((t - minVal) / (maxVal - minVal)) * height;

    final tubeRect = Rect.fromLTRB(centerX - 8, top, centerX + 8, bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)),
      Paint()
        ..color = isDark ? Colors.white12 : const Color(0xFFE0E3E8)
        ..style = PaintingStyle.fill,
    );

    // Graduations
    for (int t = minVal; t <= maxVal; t += 2) {
      final double y = yFromTemp(t);
      final bool isZero = t == 0;
      canvas.drawLine(
        Offset(centerX + 12, y),
        Offset(centerX + (isZero ? 24 : 18), y),
        Paint()
          ..color = isZero ? Colors.blue : (isDark ? Colors.white38 : Colors.black38)
          ..strokeWidth = isZero ? 2 : 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$t°C',
          style: TextStyle(
            fontSize: 10,
            color: isZero
                ? Colors.blue
                : (isDark ? Colors.white54 : Colors.black54),
            fontWeight: isZero ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX + 28, y - tp.height / 2));
    }

    // Points
    for (final p in points) {
      final double y = yFromTemp(p.value);
      canvas.drawCircle(Offset(centerX, y), 6, Paint()..color = p.color);
      final tp = TextPainter(
        text: TextSpan(
          text: '${p.name} (${p.value}°C)',
          style: TextStyle(
            fontSize: 11,
            color: p.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width - 16, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _UniversalThermometerPainter oldDelegate) => true;
}

// --- PAINTER FRACTION DYNAMIQUE ---
class _UniversalFractionPainter extends CustomPainter {
  final int numerator;
  final int denominator;
  final bool isDisk;
  final Color color;
  final bool isDark;

  _UniversalFractionPainter({
    required this.numerator,
    required this.denominator,
    required this.isDisk,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isDisk) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = math.min(size.width, size.height) / 2 - 8;

      final bgPaint = Paint()
        ..color = isDark ? Colors.white10 : const Color(0xFFF0F2F5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, bgPaint);

      final double sweepPerSlice = 2 * math.pi / denominator;
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int i = 0; i < numerator && i < denominator; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2 + i * sweepPerSlice,
          sweepPerSlice,
          true,
          fillPaint,
        );
      }

      final borderPaint = Paint()
        ..color = isDark ? Colors.white38 : Colors.black38
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < denominator; i++) {
        final double angle = -math.pi / 2 + i * sweepPerSlice;
        final p = Offset(
            center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
        canvas.drawLine(center, p, borderPaint);
      }
      canvas.drawCircle(center, radius, borderPaint);
    } else {
      // Barre rectangulaire
      final double w = size.width - 16;
      const double h = 48.0;
      final rect = Rect.fromLTWH(8, (size.height - h) / 2, w, h);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = isDark ? Colors.white10 : const Color(0xFFF0F2F5)
          ..style = PaintingStyle.fill,
      );

      final double cellW = w / denominator;
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int i = 0; i < numerator && i < denominator; i++) {
        final r = Rect.fromLTWH(8 + i * cellW, rect.top, cellW, h);
        canvas.drawRect(r, fillPaint);
      }

      final borderPaint = Paint()
        ..color = isDark ? Colors.white38 : Colors.black38
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (int i = 1; i < denominator; i++) {
        final double x = 8 + i * cellW;
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), borderPaint);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UniversalFractionPainter oldDelegate) => true;
}
