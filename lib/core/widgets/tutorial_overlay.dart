import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tutorial_service.dart';

// ── Forme du spotlight ────────────────────────────────────────────────────────

enum SpotShape { circle, roundedRect }

// ── Modèle d'une étape ────────────────────────────────────────────────────────

class TutorialStep {
  final GlobalKey? targetKey;

  /// Second targetKey optionnel (ex : 2 boutons à entourer simultanément)
  final GlobalKey? targetKey2;

  /// Calculateur dynamique de zone cible (idéal pour la barre de navigation ou zones fixes)
  final Rect Function(Size screenSize)? customTargetBuilder;

  final String title;
  final String description;
  final String? category;
  final IconData? icon;
  final List<String>? highlights;
  final double spotRadius;
  final SpotShape spotShape;
  final EdgeInsets? padding;

  const TutorialStep({
    this.targetKey,
    this.targetKey2,
    this.customTargetBuilder,
    required this.title,
    required this.description,
    this.category,
    this.icon,
    this.highlights,
    this.spotRadius = 24,
    this.spotShape = SpotShape.circle,
    this.padding,
  });
}

// ── Overlay de présentation ───────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onDone;
  final String? tutorialId;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onDone,
    this.tutorialId,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _current = 0;

  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _morphCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _morphAnim;

  // Rectangles de découpe pour l'interpolation fluide entre étapes
  Rect _prevRect = Rect.zero;
  Rect _targetRect = Rect.zero;
  SpotShape _targetShape = SpotShape.circle;
  double _targetCornerRadius = 16.0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeOutCubic);

    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _computeTarget(animate: false);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  void _computeTarget({bool animate = true}) {
    if (_current >= widget.steps.length) return;
    final step = widget.steps[_current];
    final screen = MediaQuery.of(context).size;

    Rect calculated = Rect.zero;
    SpotShape shape = step.spotShape;
    double cornerRadius = step.spotRadius;

    // 1. Calculateur personnalisé prioritaire
    if (step.customTargetBuilder != null) {
      calculated = step.customTargetBuilder!(screen);
    } else if (step.targetKey != null) {
      // 2. Calcul par GlobalKey
      final box = step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        final size = box.size;

        if (step.targetKey2 != null) {
          final box2 = step.targetKey2!.currentContext?.findRenderObject() as RenderBox?;
          if (box2 != null && box2.hasSize) {
            final pos2 = box2.localToGlobal(Offset.zero);
            final r1 = pos & size;
            final r2 = pos2 & box2.size;
            calculated = r1.expandToInclude(r2);
          } else {
            calculated = pos & size;
          }
        } else {
          calculated = pos & size;
        }

        // Padding spécifique ou par défaut
        final pad = step.padding ?? const EdgeInsets.all(8);
        calculated = Rect.fromLTRB(
          (calculated.left - pad.left).clamp(0.0, screen.width),
          (calculated.top - pad.top).clamp(0.0, screen.height),
          (calculated.right + pad.right).clamp(0.0, screen.width),
          (calculated.bottom + pad.bottom).clamp(0.0, screen.height),
        );
      }
    }

    if (calculated != Rect.zero) {
      if (shape == SpotShape.circle) {
        final radius = math.max(
          step.spotRadius,
          math.max(calculated.width, calculated.height) / 2 + 4,
        );
        calculated = Rect.fromCircle(
          center: calculated.center,
          radius: radius,
        );
      } else {
        cornerRadius = math.min(
          step.spotRadius,
          math.min(calculated.width, calculated.height) / 2,
        );
      }
    }

    setState(() {
      _prevRect = animate && _targetRect != Rect.zero ? _targetRect : calculated;
      _targetRect = calculated;
      _targetShape = shape;
      _targetCornerRadius = cornerRadius;
    });

    if (animate) {
      _morphCtrl.forward(from: 0.0);
    } else {
      _morphCtrl.value = 1.0;
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_current < widget.steps.length - 1) {
      setState(() => _current++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeTarget(animate: true));
    } else {
      _finish();
    }
  }

  void _previous() {
    HapticFeedback.lightImpact();
    if (_current > 0) {
      setState(() => _current--);
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeTarget(animate: true));
    }
  }

  bool _isFinishing = false;

  void _finish() {
    if (_isFinishing) return;
    _isFinishing = true;
    HapticFeedback.mediumImpact();
    TutorialService.markDone(widget.tutorialId);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_current];
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.of(context).size;
    final isLast = _current == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              // ── 0. Bloqueur d'interactions plein écran (rend l'écran sous-jacent inactif) ──
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Absorbe les clics sur l'écran pour éviter toute interaction avec la page
                  },
                ),
              ),

              // ── 1. Fond découpé animé avec halo ─────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_morphAnim, _pulseAnim]),
                    builder: (context, _) {
                      final currentRect = Rect.lerp(
                        _prevRect,
                        _targetRect,
                        _morphAnim.value,
                      ) ?? _targetRect;

                      return CustomPaint(
                        painter: _ModernSpotlightPainter(
                          targetRect: currentRect,
                          shape: _targetShape,
                          cornerRadius: _targetCornerRadius,
                          pulseScale: _pulseAnim.value,
                          primaryColor: primary,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── 2. Flèche en arc dynamique (IgnorePointer pour ne pas bloquer l'écran) ──
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_morphAnim, _pulseAnim]),
                    builder: (context, _) {
                      final currentRect = Rect.lerp(
                        _prevRect,
                        _targetRect,
                        _morphAnim.value,
                      ) ?? _targetRect;

                      final textRect = _calculateTextRect(
                        screen: screen,
                        targetRect: currentRect,
                      );

                      return CustomPaint(
                        painter: _CurvedArcArrowPainter(
                          targetRect: currentRect,
                          textRect: textRect,
                          color: primary,
                          pulse: _pulseAnim.value,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── 3. Texte explicatif grand format ─────────────────────────
              AnimatedBuilder(
                animation: _morphAnim,
                builder: (context, _) {
                  final currentRect = Rect.lerp(
                    _prevRect,
                    _targetRect,
                    _morphAnim.value,
                  ) ?? _targetRect;

                  return _buildFloatingExplanation(
                    context: context,
                    step: step,
                    targetRect: currentRect,
                    screen: screen,
                    primary: primary,
                    isDark: isDark,
                    isLast: isLast,
                  );
                },
              ),

              // ── 4. Bouton Sauter / Passer (AU PREMIER PLAN ABSOLU) ───────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.65),
                          child: InkWell(
                            onTap: _finish,
                            splashColor: primary.withValues(alpha: 0.35),
                            highlightColor: Colors.white.withValues(alpha: 0.15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Passer l'intro",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calcule la position géométrique estimée du bloc de texte pour le traceur de flèche
  Rect _calculateTextRect({required Size screen, required Rect targetRect}) {
    final textWidth = math.min(screen.width - 48.0, 520.0);
    final textLeft = (screen.width - textWidth) / 2;
    const estimatedHeight = 220.0;

    if (targetRect == Rect.zero) {
      return Rect.fromLTWH(textLeft, (screen.height - estimatedHeight) / 2, textWidth, estimatedHeight);
    } else if (targetRect.center.dy < screen.height * 0.48) {
      // Cible en haut : texte en dessous
      final top = (targetRect.bottom + 65.0).clamp(30.0, screen.height - estimatedHeight - 20.0);
      return Rect.fromLTWH(textLeft, top, textWidth, estimatedHeight);
    } else {
      // Cible en bas : texte au-dessus
      final bottom = (screen.height - targetRect.top + 65.0).clamp(30.0, screen.height - estimatedHeight - 20.0);
      final top = screen.height - bottom - estimatedHeight;
      return Rect.fromLTWH(textLeft, top, textWidth, estimatedHeight);
    }
  }

  // ── Texte Flottant Stylé et Épuré (Sans Fond Blanc) ───────────────────────

  Widget _buildFloatingExplanation({
    required BuildContext context,
    required TutorialStep step,
    required Rect targetRect,
    required Size screen,
    required Color primary,
    required bool isDark,
    required bool isLast,
  }) {
    final textWidth = math.min(screen.width - 48.0, 520.0);

    // Calcul de l'ancrage vertical
    double? top;
    double? bottom;

    if (targetRect == Rect.zero) {
      top = (screen.height / 2) - 130;
    } else if (targetRect.center.dy < screen.height * 0.48) {
      top = (targetRect.bottom + 65.0).clamp(30.0, screen.height - 300.0);
    } else {
      bottom = (screen.height - targetRect.top + 65.0).clamp(30.0, screen.height - 300.0);
    }

    return Positioned(
      left: 24,
      right: 24,
      top: top,
      bottom: bottom,
      child: Center(
        child: SizedBox(
          width: textWidth,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_current),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badge Catégorie Lumineux ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        step.icon ?? Icons.auto_stories_rounded,
                        size: 15,
                        color: primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.category ?? 'FONCTIONNALITÉ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Étape ${_current + 1} / ${widget.steps.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Titre Grand Format et Stylé ───────────────────────────
                Text(
                  step.title,
                  style: GoogleFonts.outfit(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.9),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── Description Aérée et Lisible ──────────────────────────
                Text(
                  step.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                // ── Points Clés / Highlights ──────────────────────────────
                if (step.highlights != null && step.highlights!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: step.highlights!.map((h) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: primary),
                            const SizedBox(width: 6),
                            Text(
                              h,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 22),

                // ── Barre de Contrôles et Pagination ──────────────────────
                Row(
                  children: [
                    // Indicateurs de progression étirables
                    Row(
                      children: List.generate(widget.steps.length, (i) {
                        final active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 26 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? primary : Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const Spacer(),

                    // Bouton Précédent
                    if (_current > 0) ...[
                      OutlinedButton(
                        onPressed: _previous,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Retour',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Bouton Suivant / C'est parti
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 4,
                        shadowColor: primary.withValues(alpha: 0.65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? "C'est parti ! 🚀" : 'Suivant',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painter spotlight moderne avec dégradé et halo ─────────────────────────────

class _ModernSpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final SpotShape shape;
  final double cornerRadius;
  final double pulseScale;
  final Color primaryColor;
  final bool isDark;

  const _ModernSpotlightPainter({
    required this.targetRect,
    required this.shape,
    required this.cornerRadius,
    required this.pulseScale,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.78 : 0.72);

    if (targetRect == Rect.zero) {
      canvas.drawRect(Offset.zero & size, bgPaint);
      return;
    }

    // Découpe nette de la zone avec evenOdd
    final path = Path()..addRect(Offset.zero & size);

    if (shape == SpotShape.circle) {
      path.addOval(targetRect);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(cornerRadius)),
      );
    }

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // ── Halo doux et anneau d'accentuation pulsant ──────────────────────────
    final center = targetRect.center;
    final haloRect = Rect.fromCenter(
      center: center,
      width: targetRect.width * pulseScale,
      height: targetRect.height * pulseScale,
    );

    // Bordure animée élégante
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (shape == SpotShape.circle) {
      canvas.drawOval(haloRect, ringPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          haloRect,
          Radius.circular(cornerRadius * pulseScale),
        ),
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ModernSpotlightPainter old) =>
      old.targetRect != targetRect ||
      old.cornerRadius != cornerRadius ||
      old.pulseScale != pulseScale ||
      old.primaryColor != primaryColor;
}

// ── Painter de Flèche en Arc Courbé Moderne ───────────────────────────────────

class _CurvedArcArrowPainter extends CustomPainter {
  final Rect targetRect;
  final Rect textRect;
  final Color color;
  final double pulse;

  const _CurvedArcArrowPainter({
    required this.targetRect,
    required this.textRect,
    required this.color,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect == Rect.zero || targetRect.isEmpty || textRect == Rect.zero) {
      return;
    }

    final isTargetAbove = targetRect.center.dy < textRect.center.dy;

    // Détermination de l'ancrage horizontal
    final targetX = targetRect.center.dx.clamp(
      targetRect.left + 16.0,
      targetRect.right - 16.0,
    );
    final textCenterX = textRect.center.dx;
    final dxToTarget = targetX - textCenterX;

    // On ancre le départ légèrement vers le côté de la cible
    final arrowStartX = (textCenterX + (dxToTarget * 0.35)).clamp(
      textRect.left + 30.0,
      textRect.right - 30.0,
    );

    final Offset p0;
    final Offset p2;

    if (isTargetAbove) {
      // Flèche vers le HAUT (vers le bas de la cible)
      p0 = Offset(arrowStartX, textRect.top - 6.0);
      p2 = Offset(targetX, targetRect.bottom + 9.0);
    } else {
      // Flèche vers le BAS (vers le haut de la cible)
      p0 = Offset(arrowStartX, textRect.bottom + 6.0);
      p2 = Offset(targetX, targetRect.top - 9.0);
    }

    // Point de contrôle pour créer un bel arc courbé fluide
    final midY = (p0.dy + p2.dy) / 2;
    final curveBend = (p2.dx >= p0.dx) ? -42.0 : 42.0;
    final p1 = Offset(
      p0.dx + ((p2.dx - p0.dx) * 0.45) + curveBend,
      midY,
    );

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);

    // 1. Halo d'ambiance doux
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 6.5 * pulse
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glowPaint);

    // 2. Trait principal courbé
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // 3. Point d'ancrage de départ (point lumineux)
    canvas.drawCircle(p0, 3.5, Paint()..color = color);
    canvas.drawCircle(p0, 6.0, Paint()..color = color.withValues(alpha: 0.35));

    // 4. Pointe de flèche dynamique tangente au point d'arrivée
    final tangentDx = p2.dx - p1.dx;
    final tangentDy = p2.dy - p1.dy;
    final tangentAngle = math.atan2(tangentDy, tangentDx);

    const headLength = 14.0;
    const headAngle = math.pi / 5.5; // ~32 degrés

    final barb1 = Offset(
      p2.dx - headLength * math.cos(tangentAngle - headAngle),
      p2.dy - headLength * math.sin(tangentAngle - headAngle),
    );
    final barb2 = Offset(
      p2.dx - headLength * math.cos(tangentAngle + headAngle),
      p2.dy - headLength * math.sin(tangentAngle + headAngle),
    );

    final headPath = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(barb1.dx, barb1.dy)
      ..lineTo(barb2.dx, barb2.dy)
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CurvedArcArrowPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.textRect != textRect ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color;
  }
}

// ── Bouton Ampoule Réutilisable pour l'AppBar ─────────────────────────────────

class TutorialLightbulbButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final GlobalKey? buttonKey;

  const TutorialLightbulbButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Guide de la page',
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.lightbulb_rounded,
          size: 19,
          color: primary,
        ),
      ),
      onPressed: onTap,
    );
  }
}
