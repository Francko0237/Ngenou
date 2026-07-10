import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';

/// Overlay de splash posé AU-DESSUS du [MaterialApp].
/// Une seule exécution par session : 5 s puis fondu de sortie.
class SplashOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onComplete;

  const SplashOverlay({super.key, required this.child, this.onComplete});

  /// Évite de réafficher le splash si l'arbre se reconstruit (ex. chargement du thème).
  static bool sessionComplete = false;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _fadeIn;
  Animation<double>? _scale;
  Animation<double>? _fadeOut;

  bool _showSplash = !SplashOverlay.sessionComplete;
  Timer? _dismissTimer;
  bool _dismissScheduled = false;

  /// Fin de l'intro (avant l'intervalle de fondu de sortie à 0.72).
  static const _introEnd = 0.71;

  static const _minDisplayDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (!_showSplash) return;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    final ctrl = _ctrl!;
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.0, 0.4)),
    );
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: ctrl,
        curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
      ),
    );

    // Intro uniquement — on s'arrête avant le fondu de sortie (0.72+).
    ctrl.animateTo(_introEnd, duration: const Duration(milliseconds: 1400));

    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleDismiss());
  }

  void _scheduleDismiss() {
    if (!mounted || !_showSplash || _dismissScheduled) return;
    _dismissScheduled = true;
    _dismissTimer = Timer(_minDisplayDuration, _dismissSplash);
  }

  Future<void> _dismissSplash() async {
    if (!mounted || !_showSplash) return;
    await _ctrl!.animateTo(1.0, duration: const Duration(milliseconds: 560));
    if (!mounted || !_showSplash) return;
    SplashOverlay.sessionComplete = true;
    setState(() => _showSplash = false);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;

    final themeMode = context.watch<ThemeProvider>().themeMode;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformDark);
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _ctrl!,
            builder: (_, __) {
              return Opacity(
                opacity: _fadeOut!.value,
                child: Material(
                  color: bg,
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: [
                    Positioned(
                      top: -60,
                      right: -60,
                      child: Opacity(
                        opacity: _fadeIn!.value * (isDark ? 0.18 : 0.07),
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -40,
                      child: Opacity(
                        opacity: _fadeIn!.value * (isDark ? 0.12 : 0.05),
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: FadeTransition(
                        opacity: _fadeIn!,
                        child: Transform.scale(
                          scale: _scale!.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 320,
                                height: 320,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                'Ngenou',
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Apprends. Progresse. Maîtrise.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subColor,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 64),
                              SizedBox(
                                width: 130,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    backgroundColor: accent.withOpacity(0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accent.withOpacity(0.75),
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
