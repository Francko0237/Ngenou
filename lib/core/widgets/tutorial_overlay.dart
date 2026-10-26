import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

// ── Forme du spotlight ────────────────────────────────────────────────────────

enum SpotShape { circle, roundedRect }

// ── Modèle d'une étape ────────────────────────────────────────────────────────

class TutorialStep {
  final GlobalKey? targetKey;

  /// Second targetKey optionnel (ex : Quotidien + Explorer simultanément)
  final GlobalKey? targetKey2;
  final String title;
  final String description;
  final double spotRadius;
  final SpotShape spotShape;

  const TutorialStep({
    this.targetKey,
    this.targetKey2,
    required this.title,
    required this.description,
    this.spotRadius = 36,
    this.spotShape = SpotShape.circle,
  });
}

// ── Overlay ───────────────────────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onDone;
  const TutorialOverlay({super.key, required this.steps, required this.onDone});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _current = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  // Spot principal
  Offset _spotCenter = Offset.zero;
  Size _spotSize = Size.zero;
  // Spot secondaire (optionnel)
  Offset _spot2Center = Offset.zero;
  Size _spot2Size = Size.zero;
  bool _hasSpot2 = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSpots());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Mesure des éléments ciblés ────────────────────────────────────────────

  ({Offset center, Size size}) _measureKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return (center: Offset.zero, size: Size.zero);
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return (center: Offset.zero, size: Size.zero);
    final pos = box.localToGlobal(Offset.zero);
    final sz = box.size;
    return (
      center: Offset(pos.dx + sz.width / 2, pos.dy + sz.height / 2),
      size: sz,
    );
  }

  void _updateSpots() {
    final step = widget.steps[_current];
    if (step.targetKey == null) {
      if (mounted)
        setState(() {
          _spotCenter = Offset.zero;
          _spotSize = Size.zero;
          _spot2Center = Offset.zero;
          _spot2Size = Size.zero;
          _hasSpot2 = false;
        });
      return;
    }

    final m1 = _measureKey(step.targetKey!);
    Offset c2 = Offset.zero;
    Size s2 = Size.zero;
    bool has2 = false;

    if (step.targetKey2 != null) {
      final m2 = _measureKey(step.targetKey2!);
      c2 = m2.center;
      s2 = m2.size;
      has2 = c2 != Offset.zero;
    }

    if (mounted) {
      setState(() {
        _spotCenter = m1.center;
        _spotSize = m1.size;
        _spot2Center = c2;
        _spot2Size = s2;
        _hasSpot2 = has2;
      });
    }
  }

  void _next() {
    if (_current < widget.steps.length - 1) {
      setState(() => _current++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateSpots());
    } else {
      _finish();
    }
  }

  void _finish() {
    TutorialService.markDone();
    _fadeCtrl.reverse().then((_) {
      if (mounted) widget.onDone();
    });
  }

  // ── Position de la bulle ──────────────────────────────────────────────────

  _BubblePos _bubblePos(BuildContext context) {
    if (_spotCenter == Offset.zero) return _BubblePos.center;
    final h = MediaQuery.of(context).size.height;
    // Si les deux spots existent, utilise le plus bas pour le calcul
    final refY = _hasSpot2
        ? math.max(_spotCenter.dy, _spot2Center.dy)
        : _spotCenter.dy;
    final rel = refY / h;
    if (rel < 0.38) return _BubblePos.below;
    if (rel > 0.62) return _BubblePos.above;
    return _BubblePos.center;
  }

  // Centre effectif entre les deux spots (ou spot seul)
  Offset get _effectiveCenter => _hasSpot2
      ? Offset(
          (_spotCenter.dx + _spot2Center.dx) / 2,
          (_spotCenter.dy + _spot2Center.dy) / 2,
        )
      : _spotCenter;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_current];
    final primary = Theme.of(context).primaryColor;
    final screenSize = MediaQuery.of(context).size;
    final bpos = _bubblePos(context);
    final isLast = _current == widget.steps.length - 1;
    final hasSpot = _spotCenter != Offset.zero;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── Fond sombre + découpe(s) ────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                painter: _SpotlightPainter(
                  center: _spotCenter,
                  size: _spotSize,
                  shape: step.spotShape,
                  radius: step.spotRadius * _pulseAnim.value,
                  center2: _hasSpot2 ? _spot2Center : null,
                  size2: _hasSpot2 ? _spot2Size : null,
                  radius2: step.spotRadius * _pulseAnim.value,
                  hasSpot: hasSpot,
                ),
              ),
            ),
          ),

          // ── Anneaux pulsants ────────────────────────────────────────────
          if (hasSpot)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                return Stack(
                  children: [
                    _buildRing(
                      _spotCenter,
                      step.spotRadius,
                      step.spotShape,
                      _spotSize,
                      primary,
                    ),
                    if (_hasSpot2)
                      _buildRing(
                        _spot2Center,
                        step.spotRadius,
                        SpotShape.circle,
                        _spot2Size,
                        primary,
                      ),
                  ],
                );
              },
            ),

          // ── Flèche en arc ───────────────────────────────────────────────
          if (hasSpot && bpos != _BubblePos.center)
            _buildArcArrow(context, bpos, primary, screenSize),

          // ── Bulle ───────────────────────────────────────────────────────
          _buildBubble(context, step, bpos, screenSize, primary, isLast),

          // ── Bouton Passer (haut GAUCHE) ─────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 16),
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Indicateur de progression ───────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? primary
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Anneau pulsant autour d'un spot ───────────────────────────────────────

  Widget _buildRing(
    Offset center,
    double radius,
    SpotShape shape,
    Size sz,
    Color primary,
  ) {
    final r = radius * _pulseAnim.value + 7;
    if (shape == SpotShape.roundedRect) {
      final w = sz.width + r * 2;
      final h = sz.height + r * 2;
      return Positioned(
        left: center.dx - w / 2,
        top: center.dy - h / 2,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20 + r),
            border: Border.all(
              color: primary.withValues(alpha: 0.55),
              width: 2,
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primary.withValues(alpha: 0.55), width: 2),
        ),
      ),
    );
  }

  // ── Flèche en arc (courbe de Bézier) ──────────────────────────────────────

  Widget _buildArcArrow(
    BuildContext context,
    _BubblePos pos,
    Color primary,
    Size screenSize,
  ) {
    // Point de départ : bord de la bulle côté élément
    // Point d'arrivée : bord du spotlight côté bulle
    // La flèche part du centre de l'écran horizontalement, courbe vers le spot

    final eff = _effectiveCenter;
    final step = widget.steps[_current];

    // Offset de départ (proche du bord de la bulle)
    double startX = eff.dx;
    double startY;
    double endY;

    if (pos == _BubblePos.below) {
      // Bulle en dessous → flèche part du haut de la bulle vers le spot en haut
      startY = eff.dy + step.spotRadius + 52;
      endY = eff.dy + step.spotRadius + 4;
    } else {
      // Bulle au-dessus → flèche part du bas de la bulle vers le spot en bas
      startY = eff.dy - step.spotRadius - 52;
      endY = eff.dy - step.spotRadius - 4;
    }

    return Positioned.fill(
      child: CustomPaint(
        painter: _ArcArrowPainter(
          start: Offset(startX, startY),
          end: Offset(eff.dx, endY),
          color: primary,
          pointingUp: pos == _BubblePos.below,
        ),
      ),
    );
  }

  // ── Bulle d'explication ────────────────────────────────────────────────────

  Widget _buildBubble(
    BuildContext context,
    TutorialStep step,
    _BubblePos pos,
    Size screen,
    Color primary,
    bool isLast,
  ) {
    final w = math.min(screen.width - 40.0, 360.0);
    const pad = 20.0;

    double? top, bottom;

    // Calcul Y de la bulle selon position
    switch (pos) {
      case _BubblePos.below:
        // Légèrement en bas du spotlight + espace pour la flèche
        top = (_spotCenter.dy + step.spotRadius + 70).clamp(
          100.0,
          screen.height - 250.0,
        );
        break;
      case _BubblePos.above:
        bottom = (screen.height - _effectiveCenter.dy + step.spotRadius + 70)
            .clamp(100.0, screen.height - 250.0);
        break;
      case _BubblePos.center:
        top = screen.height / 2 - 100;
        break;
    }

    return Positioned(
      left: pad,
      right: pad,
      top: top,
      bottom: bottom,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey(_current),
            width: w,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            decoration: BoxDecoration(
              // Fond sombre semi-transparent (pas blanc)
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Numéro étape
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_current + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Titre — grand, centré, blanc
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Description — centré
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 18),
                // Bouton Suivant / Terminer
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isLast ? 'Terminer 🎉' : 'Suivant →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Enum position bulle ───────────────────────────────────────────────────────

enum _BubblePos { above, below, center }

// ── Painter : fond sombre + découpe(s) ───────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final Size size;
  final SpotShape shape;
  final double radius;
  final Offset? center2;
  final Size? size2;
  final double radius2;
  final bool hasSpot;

  const _SpotlightPainter({
    required this.center,
    required this.size,
    required this.shape,
    required this.radius,
    this.center2,
    this.size2,
    required this.radius2,
    required this.hasSpot,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);

    if (!hasSpot) {
      canvas.drawRect(Offset.zero & canvasSize, bgPaint);
      return;
    }

    final path = Path()..addRect(Offset.zero & canvasSize);

    // Découpe spot principal
    _addCutout(path, center, size, shape, radius);

    // Découpe spot secondaire
    if (center2 != null && size2 != null) {
      _addCutout(path, center2!, size2!, SpotShape.circle, radius2);
    }

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);
  }

  void _addCutout(Path path, Offset c, Size sz, SpotShape sp, double r) {
    if (sp == SpotShape.roundedRect) {
      final rr = math.max(r, 16.0);
      final rect = Rect.fromCenter(
        center: c,
        width: sz.width + r * 1.2,
        height: sz.height + r * 1.2,
      );
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rr)));
    } else {
      path.addOval(Rect.fromCircle(center: c, radius: r));
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.center2 != center2 ||
      old.radius2 != radius2;
}

// ── Painter flèche en arc (Bézier cubique) ────────────────────────────────────

class _ArcArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final bool pointingUp; // true = flèche pointe vers le haut

  const _ArcArrowPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.pointingUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Décalage horizontal pour donner un aspect courbé naturel
    final dx = 28.0;
    final cp1 = Offset(start.dx + dx, start.dy);
    final cp2 = Offset(end.dx + dx, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

    canvas.drawPath(path, paint);

    // Pointe de flèche
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Direction tangente à l'arrivée
    final t = 0.95;
    final tx = _cubicPoint(start.dx, cp1.dx, cp2.dx, end.dx, t);
    final ty = _cubicPoint(start.dy, cp1.dy, cp2.dy, end.dy, t);
    final angle = math.atan2(end.dy - ty, end.dx - tx);
    const headLen = 10.0;
    const headAngle = 0.45;

    canvas.drawLine(
      Offset(end.dx, end.dy),
      Offset(
        end.dx - headLen * math.cos(angle - headAngle),
        end.dy - headLen * math.sin(angle - headAngle),
      ),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(end.dx, end.dy),
      Offset(
        end.dx - headLen * math.cos(angle + headAngle),
        end.dy - headLen * math.sin(angle + headAngle),
      ),
      arrowPaint,
    );
  }

  double _cubicPoint(double p0, double p1, double p2, double p3, double t) {
    final mt = 1 - t;
    return mt * mt * mt * p0 +
        3 * mt * mt * t * p1 +
        3 * mt * t * t * p2 +
        t * t * t * p3;
  }

  @override
  bool shouldRepaint(_ArcArrowPainter old) =>
      old.start != start || old.end != end;
}
