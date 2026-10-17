import 'package:flutter/material.dart';

class NombresRelatifsPage extends StatefulWidget {
  const NombresRelatifsPage({super.key});

  @override
  State<NombresRelatifsPage> createState() => _NombresRelatifsPageState();
}

class _NombresRelatifsPageState extends State<NombresRelatifsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mode 1 : Explorer & Comparer
  int _pointValA = -3;
  int _pointValB = 4;
  bool _isVerticalThermometer = false;

  // Mode 2 : Calculer (Opérations)
  int _terme1 = -2;
  int _terme2 = 5;
  String _operateur = '+'; // '+' ou '-'

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF3498DB);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E12) : const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text(
          'Droite Graduée & Relatifs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.linear_scale_rounded), text: 'Repérer & Comparer'),
            Tab(icon: Icon(Icons.calculate_rounded), text: 'Calculer pas-à-pas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExplorerTab(isDark, accentColor),
          _buildCalculatorTab(isDark, accentColor),
        ],
      ),
    );
  }

  // --- ONGLET 1 : EXPLORER & COMPARER ---
  Widget _buildExplorerTab(bool isDark, Color accentColor) {
    final int distA = _pointValA.abs();
    final int distB = _pointValB.abs();
    final bool sontEgaux = _pointValA == _pointValB;
    final bool aSuperieur = _pointValA > _pointValB;

    String explicationComparaison;
    if (sontEgaux) {
      explicationComparaison = 'Les deux points sont confondus ($pointStr(_pointValA)).';
    } else if (_pointValA >= 0 && _pointValB < 0) {
      explicationComparaison =
          'Tout nombre positif (${pointStr(_pointValA)}) est supérieur à tout nombre négatif (${pointStr(_pointValB)}).';
    } else if (_pointValA < 0 && _pointValB >= 0) {
      explicationComparaison =
          'Tout nombre négatif (${pointStr(_pointValA)}) est inférieur à tout nombre positif (${pointStr(_pointValB)}).';
    } else if (_pointValA >= 0 && _pointValB >= 0) {
      explicationComparaison =
          'Entre deux nombres positifs, le plus grand est celui qui a la plus grande distance à zéro ($distA > $distB).';
    } else {
      explicationComparaison =
          'Entre deux nombres négatifs, le plus grand est celui qui a la PLUS PETITE distance à zéro (le plus proche de zéro : $distA ${aSuperieur ? '<' : '>'} $distB).';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // Sélecteur Droite Horizontale / Thermomètre
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_flat_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Droite graduée (Axe)'),
                      ],
                    ),
                    selected: !_isVerticalThermometer,
                    selectedColor: accentColor.withValues(alpha: 0.18),
                    onSelected: (val) =>
                        setState(() => _isVerticalThermometer = false),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.thermostat_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Thermomètre (°C)'),
                      ],
                    ),
                    selected: _isVerticalThermometer,
                    selectedColor: accentColor.withValues(alpha: 0.18),
                    onSelected: (val) =>
                        setState(() => _isVerticalThermometer = true),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Zone de dessin
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
                    if (!_isVerticalThermometer)
                      SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _DroitePainter(
                            pointValA: _pointValA,
                            pointValB: _pointValB,
                            isDark: isDark,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        width: 160,
                        child: CustomPaint(
                          painter: _ThermometerPainter(
                            tempA: _pointValA,
                            tempB: _pointValB,
                            isDark: isDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Contrôles des deux points
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
                    // Curseur Point A
                    _buildPointSlider(
                      label: 'Point A (bleu)',
                      value: _pointValA,
                      color: const Color(0xFF3498DB),
                      onChanged: (v) => setState(() => _pointValA = v),
                    ),
                    const Divider(height: 20),
                    // Curseur Point B
                    _buildPointSlider(
                      label: 'Point B (orange)',
                      value: _pointValB,
                      color: const Color(0xFFE67E22),
                      onChanged: (v) => setState(() => _pointValB = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bilan pédagogique de la comparaison
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'A (${pointStr(_pointValA)})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3498DB),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              sontEgaux ? '=' : (aSuperieur ? '>' : '<'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'B (${pointStr(_pointValB)})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE67E22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      explicationComparaison,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
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

  // --- ONGLET 2 : CALCULER PAS-À-PAS ---
  Widget _buildCalculatorTab(bool isDark, Color accentColor) {
    final int depart = _terme1;
    final int arrivee = _operateur == '+' ? (_terme1 + _terme2) : (_terme1 - _terme2);
    final int opposeTerme2 = -_terme2;

    String regleDetaillee;
    if (_operateur == '+') {
      if ((_terme1 >= 0 && _terme2 >= 0) || (_terme1 <= 0 && _terme2 <= 0)) {
        regleDetaillee =
            'Même signe : on garde le signe et on additionne les distances à zéro (${_terme1.abs()} + ${_terme2.abs()} = ${arrivee.abs()}).';
      } else {
        final int plusGrand = _terme1.abs() >= _terme2.abs() ? _terme1 : _terme2;
        regleDetaillee =
            'Signes contraires : le résultat prend le signe de $plusGrand (le plus éloigné de zéro).';
      }
    } else {
      regleDetaillee =
          'Règle d\'or : Soustraire un nombre relatif revient à ajouter son opposé !\n(${pointStr(_terme1)}) - (${pointStr(_terme2)}) = (${pointStr(_terme1)}) + (${pointStr(opposeTerme2)}) = ${pointStr(arrivee)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // Zone de visualisation du vecteur de déplacement
              Container(
                width: double.infinity,
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
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _DroitePainter(
                          deplacementDepart: depart,
                          deplacementArrivee: arrivee,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Affichage de l'opération en grand
                    Text(
                      '($pointStr(_terme1)) $_operateur ($pointStr(_terme2)) = $pointStr(arrivee)',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sélecteur des termes et de l'opération
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
                    _buildPointSlider(
                      label: 'Premier terme',
                      value: _terme1,
                      color: const Color(0xFF3498DB),
                      onChanged: (v) => setState(() => _terme1 = v),
                    ),
                    const SizedBox(height: 10),
                    // Choix Addition / Soustraction
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('+ Addition', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _operateur == '+',
                          selectedColor: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                          onSelected: (val) => setState(() => _operateur = '+'),
                        ),
                        const SizedBox(width: 14),
                        ChoiceChip(
                          label: const Text('− Soustraction', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _operateur == '-',
                          selectedColor: const Color(0xFFE74C3C).withValues(alpha: 0.2),
                          onSelected: (val) => setState(() => _operateur = '-'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildPointSlider(
                      label: 'Second terme',
                      value: _terme2,
                      color: const Color(0xFFE67E22),
                      onChanged: (v) => setState(() => _terme2 = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Explication de la règle
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.school_rounded, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Règle du cours (5ème) :',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            regleDetaillee,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
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

  Widget _buildPointSlider({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: value > -10 ? () => onChanged(value - 1) : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pointStr(value),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: value < 10 ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: -10,
          max: 10,
          divisions: 20,
          activeColor: color,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  String pointStr(int val) => val > 0 ? '+$val' : '$val';
}

class _DroitePainter extends CustomPainter {
  static const int minVal = -10;
  static const int maxVal = 10;
  final int? pointValA;
  final int? pointValB;
  final int? deplacementDepart;
  final int? deplacementArrivee;
  final bool isDark;

  _DroitePainter({
    this.pointValA,
    this.pointValB,
    this.deplacementDepart,
    this.deplacementArrivee,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double yCenter = size.height / 2;
    final double totalUnits = (maxVal - minVal).toDouble();
    final double unitWidth = size.width / totalUnits;

    double xFromVal(num val) => (val - minVal) * unitWidth;

    final axisPaint = Paint()
      ..color = isDark ? Colors.white60 : Colors.black87
      ..strokeWidth = 2.0;

    final originPaint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeWidth = 3.5;

    final tickPaint = Paint()
      ..color = isDark ? Colors.white30 : Colors.black26
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(0, yCenter), Offset(size.width, yCenter), axisPaint);

    final arrowPath = Path()
      ..moveTo(size.width, yCenter)
      ..lineTo(size.width - 10, yCenter - 5)
      ..lineTo(size.width - 10, yCenter + 5)
      ..close();
    canvas.drawPath(arrowPath, axisPaint..style = PaintingStyle.fill);

    for (int v = minVal; v <= maxVal; v++) {
      final double x = xFromVal(v);
      final bool isOrigin = v == 0;
      final double tickHeight = isOrigin ? 12 : 6;

      canvas.drawLine(
        Offset(x, yCenter - tickHeight),
        Offset(x, yCenter + tickHeight),
        isOrigin ? originPaint : tickPaint,
      );

      if (v % 2 == 0 || isOrigin) {
        final textSpan = TextSpan(
          text: isOrigin ? '0' : (v > 0 ? '+$v' : '$v'),
          style: TextStyle(
            color: isOrigin
                ? (isDark ? Colors.white : Colors.black)
                : (v > 0 ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
            fontWeight: isOrigin ? FontWeight.bold : FontWeight.w500,
            fontSize: isOrigin ? 12.5 : 10.5,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(x - (textPainter.width / 2), yCenter + 14),
        );
      }
    }

    if (deplacementDepart != null && deplacementArrivee != null) {
      final startX = xFromVal(deplacementDepart!);
      final endX = xFromVal(deplacementArrivee!);
      final bool avanceVersDroite = endX >= startX;
      final arrowColor =
          avanceVersDroite ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);

      final vectorPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final double arcHeight = yCenter - 34;
      final path = Path()
        ..moveTo(startX, yCenter - 14)
        ..quadraticBezierTo(
          (startX + endX) / 2,
          arcHeight,
          endX,
          yCenter - 14,
        );
      canvas.drawPath(path, vectorPaint);

      final tipX = endX;
      final tipY = yCenter - 14;
      final tipPath = Path()
        ..moveTo(tipX, tipY)
        ..lineTo(avanceVersDroite ? tipX - 7 : tipX + 7, tipY - 5)
        ..lineTo(avanceVersDroite ? tipX - 7 : tipX + 7, tipY + 5)
        ..close();
      canvas.drawPath(tipPath, Paint()..color = arrowColor);
    }

    if (pointValA != null) {
      _drawMarker(
        canvas: canvas,
        x: xFromVal(pointValA!),
        y: yCenter,
        label: 'A ($pointValA)',
        color: const Color(0xFF3498DB),
      );
    }

    if (pointValB != null) {
      _drawMarker(
        canvas: canvas,
        x: xFromVal(pointValB!),
        y: yCenter,
        label: 'B ($pointValB)',
        color: const Color(0xFFE67E22),
      );
    }
  }

  void _drawMarker({
    required Canvas canvas,
    required double x,
    required double y,
    required String label,
    required Color color,
  }) {
    canvas.drawCircle(Offset(x, y), 6, Paint()..color = color);
    canvas.drawCircle(
      Offset(x, y),
      8,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - (textPainter.width / 2), y - 28));
  }

  @override
  bool shouldRepaint(covariant _DroitePainter oldDelegate) {
    return oldDelegate.pointValA != pointValA ||
        oldDelegate.pointValB != pointValB ||
        oldDelegate.deplacementDepart != deplacementDepart ||
        oldDelegate.deplacementArrivee != deplacementArrivee ||
        oldDelegate.isDark != isDark;
  }
}

class _ThermometerPainter extends CustomPainter {
  final int tempA;
  final int tempB;
  final bool isDark;

  _ThermometerPainter({
    required this.tempA,
    required this.tempB,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    const double top = 20;
    final double bottom = size.height - 30;
    final double height = bottom - top;
    const int minVal = -10;
    const int maxVal = 10;

    double yFromTemp(num t) =>
        bottom - ((t - minVal) / (maxVal - minVal)) * height;

    // Tube
    final tubeRect = Rect.fromLTRB(centerX - 8, top, centerX + 8, bottom);
    final tubePaint = Paint()
      ..color = isDark ? Colors.white12 : const Color(0xFFE0E3E8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)),
      tubePaint,
    );

    // Graduations
    for (int t = minVal; t <= maxVal; t += 2) {
      final double y = yFromTemp(t);
      final bool isOrigin = t == 0;
      canvas.drawLine(
        Offset(centerX + 12, y),
        Offset(centerX + (isOrigin ? 22 : 18), y),
        Paint()
          ..color = isOrigin
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white30 : Colors.black26)
          ..strokeWidth = isOrigin ? 2.5 : 1.2,
      );

      final textSpan = TextSpan(
        text: isOrigin ? '0°C' : (t > 0 ? '+$t' : '$t'),
        style: TextStyle(
          color: isOrigin
              ? (isDark ? Colors.white : Colors.black)
              : (t > 0 ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
          fontSize: 10,
          fontWeight: isOrigin ? FontWeight.bold : FontWeight.normal,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(centerX + 26, y - 6));
    }

    // Repères des points
    _drawTempMarker(canvas, centerX - 12, yFromTemp(tempA), 'A', const Color(0xFF3498DB));
    _drawTempMarker(canvas, centerX - 12, yFromTemp(tempB), 'B', const Color(0xFFE67E22));
  }

  void _drawTempMarker(Canvas canvas, double x, double y, String label, Color color) {
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - 18, y - 6));
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) {
    return oldDelegate.tempA != tempA ||
        oldDelegate.tempB != tempB ||
        oldDelegate.isDark != isDark;
  }
}
