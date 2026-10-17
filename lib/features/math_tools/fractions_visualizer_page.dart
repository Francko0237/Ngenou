import 'dart:math' as math;
import 'package:flutter/material.dart';

class FractionsVisualizerPage extends StatefulWidget {
  const FractionsVisualizerPage({super.key});

  @override
  State<FractionsVisualizerPage> createState() =>
      _FractionsVisualizerPageState();
}

class _FractionsVisualizerPageState extends State<FractionsVisualizerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Fraction Principale (Mode Manipulation)
  int _numerateur = 3;
  int _denominateur = 4;
  bool _isPieMode = true; // true = Disque, false = Réglette

  // Comparaison (Fraction A & Fraction B)
  int _numA = 1;
  int _denA = 2;
  int _numB = 2;
  int _denB = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static int _pgcd(int a, int b) {
    int x = a.abs();
    int y = b.abs();
    while (y != 0) {
      int t = y;
      y = x % y;
      x = t;
    }
    return x == 0 ? 1 : x;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE67E22);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E12) : const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text(
          'Atelier des Fractions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline_rounded), text: 'Explorer'),
            Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Comparer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExplorerTab(isDark, accentColor),
          _buildCompareTab(isDark, accentColor),
        ],
      ),
    );
  }

  Widget _buildExplorerTab(bool isDark, Color accentColor) {
    final double valeurDecimale = _numerateur / _denominateur;
    final double pourcentage = valeurDecimale * 100;
    final int diviseur = _pgcd(_numerateur, _denominateur);
    final int numSimplifie = _numerateur ~/ diviseur;
    final int denSimplifie = _denominateur ~/ diviseur;
    final bool estIrreductible = diviseur == 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              // Sélecteur de forme (Disque ou Réglette)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Disque (Pizza)'),
                      ],
                    ),
                    selected: _isPieMode,
                    selectedColor: accentColor.withValues(alpha: 0.18),
                    onSelected: (val) => setState(() => _isPieMode = true),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_column_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Réglette (Barre)'),
                      ],
                    ),
                    selected: !_isPieMode,
                    selectedColor: accentColor.withValues(alpha: 0.18),
                    onSelected: (val) => setState(() => _isPieMode = false),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Zone de dessin interactif
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                    SizedBox(
                      height: 200,
                      width: _isPieMode ? 200 : double.infinity,
                      child: CustomPaint(
                        painter: _isPieMode
                            ? _PiePainter(
                                numerateur: _numerateur,
                                denominateur: _denominateur,
                                fillColor: accentColor,
                                emptyColor: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFEDEFF3),
                                borderColor: accentColor,
                              )
                            : _BarPainter(
                                numerateur: _numerateur,
                                denominateur: _denominateur,
                                fillColor: accentColor,
                                emptyColor: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFEDEFF3),
                                borderColor: accentColor,
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Affichage fraction mathématique
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildFractionDisplay(
                          _numerateur,
                          _denominateur,
                          accentColor,
                          fontSize: 28,
                        ),
                        const SizedBox(width: 20),
                        const Text('=', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              valeurDecimale.toStringAsFixed(valeurDecimale % 1 == 0 ? 0 : 2),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${pourcentage.toStringAsFixed(1)} %',
                              style: TextStyle(
                                fontSize: 14,
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Contrôles Numérateur et Dénominateur
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  children: [
                    // Numérateur (Parts prises)
                    Row(
                      children: [
                        const Text(
                          'Numérateur (parts prises) :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const Spacer(),
                        _stepperButton(
                          icon: Icons.remove,
                          onPressed: _numerateur > 0
                              ? () => setState(() => _numerateur--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_numerateur',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _stepperButton(
                          icon: Icons.add,
                          onPressed: _numerateur < _denominateur
                              ? () => setState(() => _numerateur++)
                              : null,
                        ),
                      ],
                    ),
                    Slider(
                      value: _numerateur.toDouble(),
                      min: 0,
                      max: _denominateur.toDouble(),
                      divisions: _denominateur,
                      activeColor: accentColor,
                      onChanged: (val) => setState(() => _numerateur = val.round()),
                    ),

                    const Divider(height: 24),

                    // Dénominateur (Parts totales)
                    Row(
                      children: [
                        const Text(
                          'Dénominateur (parts totales) :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const Spacer(),
                        _stepperButton(
                          icon: Icons.remove,
                          onPressed: _denominateur > 1
                              ? () => setState(() {
                                    _denominateur--;
                                    if (_numerateur > _denominateur) {
                                      _numerateur = _denominateur;
                                    }
                                  })
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_denominateur',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _stepperButton(
                          icon: Icons.add,
                          onPressed: _denominateur < 16
                              ? () => setState(() => _denominateur++)
                              : null,
                        ),
                      ],
                    ),
                    Slider(
                      value: _denominateur.toDouble(),
                      min: 1,
                      max: 16,
                      divisions: 15,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() {
                        _denominateur = val.round();
                        if (_numerateur > _denominateur) {
                          _numerateur = _denominateur;
                        }
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Explication de la simplification
              Container(
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF2ECC71)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fraction irréductible',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            estIrreductible
                                ? 'Cette fraction ne peut plus être simplifiée.'
                                : 'Simplifiée par $diviseur : $_numerateur/$_denominateur = $numSimplifie/$denSimplifie',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!estIrreductible)
                      _buildFractionDisplay(
                        numSimplifie,
                        denSimplifie,
                        const Color(0xFF2ECC71),
                        fontSize: 20,
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

  Widget _buildCompareTab(bool isDark, Color accentColor) {
    final double valA = _numA / _denA;
    final double valB = _numB / _denB;
    final bool sontEgales = (valA - valB).abs() < 0.0001;
    final bool aSuperieur = valA > valB;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              // Comparaison visuelle côte à côte
              Row(
                children: [
                  // Fraction A
                  Expanded(
                    child: _buildComparisonCard(
                      label: 'Fraction A',
                      numerateur: _numA,
                      denominateur: _denA,
                      color: accentColor,
                      isDark: isDark,
                      onNumChanged: (v) => setState(() => _numA = v),
                      onDenChanged: (v) => setState(() => _denA = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Symbole au milieu
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sontEgales
                          ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                          : accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      sontEgales ? '=' : (aSuperieur ? '>' : '<'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: sontEgales ? const Color(0xFF2ECC71) : accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Fraction B
                  Expanded(
                    child: _buildComparisonCard(
                      label: 'Fraction B',
                      numerateur: _numB,
                      denominateur: _denB,
                      color: Colors.blueAccent,
                      isDark: isDark,
                      onNumChanged: (v) => setState(() => _numB = v),
                      onDenChanged: (v) => setState(() => _denB = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bilan d'équivalence
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sontEgales
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF16161E) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sontEgales
                        ? const Color(0xFF2ECC71)
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: sontEgales ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sontEgales
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      color: sontEgales
                          ? const Color(0xFF2ECC71)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sontEgales
                          ? 'Fractions équivalentes ! Elles représentent exactement la même proportion.'
                          : (aSuperieur
                              ? 'Fraction A ($_numA/$_denA) est plus grande que Fraction B ($_numB/$_denB).'
                              : 'Fraction A ($_numA/$_denA) est plus petite que Fraction B ($_numB/$_denB).'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: sontEgales ? const Color(0xFF2ECC71) : null,
                        ),
                      ),
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

  Widget _buildComparisonCard({
    required String label,
    required int numerateur,
    required int denominateur,
    required Color color,
    required bool isDark,
    required ValueChanged<int> onNumChanged,
    required ValueChanged<int> onDenChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            width: 110,
            child: CustomPaint(
              painter: _PiePainter(
                numerateur: numerateur,
                denominateur: denominateur,
                fillColor: color,
                emptyColor: isDark ? Colors.white10 : const Color(0xFFF0F1F4),
                borderColor: color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFractionDisplay(numerateur, denominateur, color, fontSize: 20),
          const SizedBox(height: 12),
          // Contrôles mini
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniButton(
                icon: Icons.remove,
                onPressed: numerateur > 0 ? () => onNumChanged(numerateur - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$numerateur', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              _miniButton(
                icon: Icons.add,
                onPressed: numerateur < denominateur ? () => onNumChanged(numerateur + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniButton(
                icon: Icons.remove,
                onPressed: denominateur > 1
                    ? () {
                        final newDen = denominateur - 1;
                        onDenChanged(newDen);
                        if (numerateur > newDen) onNumChanged(newDen);
                      }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$denominateur', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              _miniButton(
                icon: Icons.add,
                onPressed: denominateur < 12 ? () => onDenChanged(denominateur + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFractionDisplay(
    int num,
    int den,
    Color color, {
    double fontSize = 24,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$num',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Container(
          width: fontSize * 1.5,
          height: 2.5,
          color: color,
        ),
        Text(
          '$den',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.grey.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onPressed != null
              ? Colors.grey.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: onPressed != null ? null : Colors.grey),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final int numerateur;
  final int denominateur;
  final Color fillColor;
  final Color emptyColor;
  final Color borderColor;

  _PiePainter({
    required this.numerateur,
    required this.denominateur,
    required this.fillColor,
    required this.emptyColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (denominateur <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final sweepAngle = (2 * math.pi) / denominateur;

    final emptyPaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final sliceBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < denominateur; i++) {
      final startAngle = -math.pi / 2 + (i * sweepAngle);
      final isFilled = i < numerateur;
      final currentPaint = isFilled ? fillPaint : emptyPaint;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        currentPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        sliceBorderPaint,
      );
    }

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.numerateur != numerateur ||
        oldDelegate.denominateur != denominateur ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.emptyColor != emptyColor;
  }
}

class _BarPainter extends CustomPainter {
  final int numerateur;
  final int denominateur;
  final Color fillColor;
  final Color emptyColor;
  final Color borderColor;

  _BarPainter({
    required this.numerateur,
    required this.denominateur,
    required this.fillColor,
    required this.emptyColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (denominateur <= 0) return;

    final widthPerSlice = size.width / denominateur;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    canvas.clipRRect(rrect);

    final emptyPaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final separatorPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), emptyPaint);

    for (int i = 0; i < denominateur; i++) {
      final rect = Rect.fromLTWH(i * widthPerSlice, 0, widthPerSlice, size.height);
      if (i < numerateur) {
        canvas.drawRect(rect, fillPaint);
      }
      if (i > 0) {
        canvas.drawLine(
          Offset(i * widthPerSlice, 0),
          Offset(i * widthPerSlice, size.height),
          separatorPaint,
        );
      }
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    return oldDelegate.numerateur != numerateur ||
        oldDelegate.denominateur != denominateur ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.emptyColor != emptyColor;
  }
}
