import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

const _kOnboardingDone = 'ngenou_onboarding_done_v1';

Future<bool> shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingDone) ?? false);
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  final List<_OnboardingStep> _steps = [
    _OnboardingStep(
      emoji: '🚀',
      title: 'Bienvenue sur Ngenou',
      subtitle: 'Ton assistant d\'apprentissage intelligent',
      body:
          'Ngenou t\'aide à apprendre plus vite, mieux organiser tes révisions et suivre ta progression en temps réel.',
      gradient: [Color(0xFF6C63FF), Color(0xFF4A90D9)],
      accentColor: Color(0xFF6C63FF),
      illustrationKey: 'welcome',
    ),
    _OnboardingStep(
      emoji: '🎓',
      title: 'Cours & Notions',
      subtitle: 'Apprends à ton rythme',
      body:
          'Parcours des cours structurés par notions, pratique avec des exercices interactifs et suis ta maîtrise de chaque sujet.',
      gradient: [Color(0xFF4A90D9), Color(0xFF3498DB)],
      accentColor: Color(0xFF4A90D9),
      illustrationKey: 'cours',
    ),
    _OnboardingStep(
      emoji: '🎯',
      title: 'Défis Quotidiens',
      subtitle: 'Reste dans le flow chaque jour',
      body:
          'Chaque jour, un nouveau défi pour tester tes connaissances. Enchaîne les streaks et débloque des badges exclusifs !',
      gradient: [Color(0xFF9B59B6), Color(0xFF6C63FF)],
      accentColor: Color(0xFF9B59B6),
      illustrationKey: 'defis',
    ),
    _OnboardingStep(
      emoji: '📅',
      title: 'Planning Intelligent',
      subtitle: 'Organise-toi comme un pro',
      body:
          'Crée ton emploi du temps de révision. Ngenou planifie automatiquement tes sessions et t\'envoie des rappels au bon moment.',
      gradient: [Color(0xFF5B52FF), Color(0xFF9B59B6)],
      accentColor: Color(0xFF5B52FF),
      illustrationKey: 'planning',
    ),
    _OnboardingStep(
      emoji: '☁️',
      title: 'Synchronisation Cloud',
      subtitle: 'Tes données, partout',
      body:
          'Connecte-toi avec Google pour sauvegarder ta progression automatiquement et y accéder depuis n\'importe quel appareil.',
      gradient: [Color(0xFF4A90D9), Color(0xFF6C63FF)],
      accentColor: Color(0xFF4A90D9),
      illustrationKey: 'cloud',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    widget.onDone();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _slideController.reset();
    _slideController.forward();
  }

  List<Widget> _buildFloatingParticles(Color color) {
    return List.generate(8, (i) {
      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          final t = (_particleController.value + i * 0.13) % 1.0;
          final size = MediaQuery.of(context).size;
          final x =
              (i * 0.15 + 0.05 + math.sin(t * 2 * math.pi + i) * 0.1)
                  .clamp(0.0, 1.0);
          final y = 1.0 - t;
          final opacity =
              (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.25;
          final particleSize = 6.0 + (i % 4) * 4.0;

          return Positioned(
            left: x * size.width,
            top: y * size.height,
            child: Opacity(
              opacity: opacity.toDouble(),
              child: Container(
                width: particleSize,
                height: particleSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: i % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: i % 2 == 0 ? null : BorderRadius.circular(2),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentPage];
    final isLast = _currentPage == _steps.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: step.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Particules flottantes
              ..._buildFloatingParticles(step.accentColor),

              // Contenu
              Column(
                children: [
                  // Skip
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, top: 8),
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          'Passer',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pages
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        return _OnboardingStepView(
                          step: _steps[index],
                          slideController: _slideController,
                          pulseController: _pulseController,
                        );
                      },
                    ),
                  ),

                  // Indicateurs
                  _PageIndicators(
                    count: _steps.length,
                    current: _currentPage,
                  ),

                  const SizedBox(height: 32),

                  // Boutons navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          opacity: _currentPage > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: _currentPage == 0,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: IconButton(
                                onPressed: _prevPage,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _NextButton(
                          isLast: isLast,
                          pulseController: _pulseController,
                          onTap: _nextPage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vue d'étape ─────────────────────────────────────────────────────────────

class _OnboardingStepView extends StatelessWidget {
  final _OnboardingStep step;
  final AnimationController slideController;
  final AnimationController pulseController;

  const _OnboardingStepView({
    required this.step,
    required this.slideController,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: slideController, curve: Curves.easeOut));

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: slideController, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration animée (pulsation)
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final scale = 1.0 + pulseController.value * 0.04;
              return Transform.scale(scale: scale, child: child);
            },
            child: _IllustrationWidget(step: step),
          ),

          const SizedBox(height: 40),

          // Textes
          SlideTransition(
            position: slideUp,
            child: FadeTransition(
              opacity: fadeIn,
              child: Column(
                children: [
                  // Badge sous-titre
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      step.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.65,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
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

// ─── Illustration ─────────────────────────────────────────────────────────────

class _IllustrationWidget extends StatelessWidget {
  final _OnboardingStep step;

  const _IllustrationWidget({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final configs = <String, _IllustrationConfig>{
      'welcome': _IllustrationConfig(
        mainEmoji: '🚀',
        decorators: [
          _Decorator(emoji: '⭐', top: 22, right: 30),
          _Decorator(emoji: '✨', bottom: 26, left: 26),
          _Decorator(emoji: '💡', top: 30, left: 28),
        ],
      ),
      'cours': _IllustrationConfig(
        mainEmoji: '🎓',
        decorators: [
          _Decorator(emoji: '📚', top: 22, right: 28),
          _Decorator(emoji: '✏️', bottom: 26, left: 28),
          _Decorator(emoji: '📝', top: 32, left: 24),
        ],
      ),
      'defis': _IllustrationConfig(
        mainEmoji: '🎯',
        decorators: [
          _Decorator(emoji: '🔥', top: 22, right: 28),
          _Decorator(emoji: '⚡', bottom: 24, left: 28),
          _Decorator(emoji: '🏆', top: 30, left: 24),
        ],
      ),
      'planning': _IllustrationConfig(
        mainEmoji: '📅',
        decorators: [
          _Decorator(emoji: '⏰', top: 22, right: 28),
          _Decorator(emoji: '✅', bottom: 24, left: 26),
          _Decorator(emoji: '🗓️', top: 28, left: 22),
        ],
      ),
      'cloud': _IllustrationConfig(
        mainEmoji: '☁️',
        decorators: [
          _Decorator(emoji: '🔄', top: 20, right: 26),
          _Decorator(emoji: '🔐', bottom: 24, left: 26),
          _Decorator(emoji: '📱', top: 30, left: 24),
        ],
      ),
    };

    final config =
        configs[step.illustrationKey] ?? _IllustrationConfig(mainEmoji: step.emoji, decorators: []);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(config.mainEmoji, style: const TextStyle(fontSize: 76)),
          ...config.decorators.map((d) => Positioned(
                top: d.top,
                bottom: d.bottom,
                left: d.left,
                right: d.right,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(d.emoji,
                      style: const TextStyle(fontSize: 16)),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Indicateurs ─────────────────────────────────────────────────────────────

class _PageIndicators extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Bouton Suivant ───────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final bool isLast;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _NextButton({
    required this.isLast,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final glow = pulseController.value * 0.3 + 0.1;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: glow),
                  blurRadius: 20 + pulseController.value * 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLast ? 'C\'est parti ! 🚀' : 'Suivant',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF2C3E50),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Modèles internes ─────────────────────────────────────────────────────────

class _OnboardingStep {
  final String emoji;
  final String title;
  final String subtitle;
  final String body;
  final List<Color> gradient;
  final Color accentColor;
  final String illustrationKey;

  const _OnboardingStep({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.gradient,
    required this.accentColor,
    required this.illustrationKey,
  });
}

class _IllustrationConfig {
  final String mainEmoji;
  final List<_Decorator> decorators;
  _IllustrationConfig({required this.mainEmoji, required this.decorators});
}

class _Decorator {
  final String emoji;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  _Decorator({
    required this.emoji,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
}
