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

/// Permet de réinitialiser l'onboarding (ex: pour revoir le guide)
Future<void> resetOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kOnboardingDone);
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

  final List<_OnboardingStep> _steps = const [
    _OnboardingStep(
      emoji: '🚀',
      title: 'Bienvenue sur Ngenou',
      subtitle: 'Ton assistant d\'apprentissage intelligent',
      body:
          'Une méthode moderne, stimulante et sans stress pour apprendre, pratiquer et exceller dans toutes tes matières.',
      gradient: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
      accentColor: Color(0xFF4F46E5),
      illustrationKey: 'welcome',
    ),
    _OnboardingStep(
      emoji: '📚',
      title: 'Cours & Notions',
      subtitle: 'Apprends à ton propre rythme',
      body:
          'Chaque cours est découpé en notions claires. Lis la leçon, pratique quand tu le souhaites (les exercices sont facultatifs) et valide ta progression.',
      gradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      accentColor: Color(0xFF0EA5E9),
      illustrationKey: 'cours',
    ),
    _OnboardingStep(
      emoji: '🤖',
      title: 'Tuteur IA Ngenou',
      subtitle: 'Une réponse claire 24h/24',
      body:
          'Un doute sur un théorème, un code ou une méthode ? Pose ta question à ton tuteur IA pour des explications simples, avec des exemples concrets.',
      gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
      accentColor: Color(0xFF7C3AED),
      illustrationKey: 'ai',
    ),
    _OnboardingStep(
      emoji: '🔥',
      title: 'Séries & Progression',
      subtitle: 'Reste motivé au quotidien',
      body:
          'Suis tes séries de jours actifs, le pourcentage de notions maîtrisées et synchronise tes révisions avec ton planning intelligent.',
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      accentColor: Color(0xFFF59E0B),
      illustrationKey: 'progression',
    ),
    _OnboardingStep(
      emoji: '🎯',
      title: 'Prêt pour le premier pas ?',
      subtitle: '3 missions simples pour démarrer',
      body:
          'Ton tableau de bord t\'attend avec une checklist guidée : ouvre un cours, teste l\'IA et découvre ton bilan.',
      gradient: [Color(0xFF10B981), Color(0xFF0284C7)],
      accentColor: Color(0xFF10B981),
      illustrationKey: 'launch',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
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

  List<Widget> _buildFloatingParticles() {
    return List.generate(8, (i) {
      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          final t = (_particleController.value + i * 0.125) % 1.0;
          final size = MediaQuery.of(context).size;
          final x =
              (i * 0.13 + 0.05 + math.sin(t * 2 * math.pi + i) * 0.08)
                  .clamp(0.0, 1.0);
          final y = 1.0 - t;
          final opacity =
              (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.22;
          final particleSize = 5.0 + (i % 3) * 4.0;

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
              ..._buildFloatingParticles(),

              // Contenu principal
              Column(
                children: [
                  // Barre du haut : Bouton passer
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, top: 10),
                      child: TextButton.icon(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.85),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(
                          'Passer',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Carousel de pages
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

                  // Indicateurs de pagination
                  _PageIndicators(
                    count: _steps.length,
                    current: _currentPage,
                  ),

                  const SizedBox(height: 28),

                  // Barre d'actions du bas
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
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
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
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vue d'une étape ──────────────────────────────────────────────────────────

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
        CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic));

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: slideController, curve: Curves.easeOut),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Illustration visuelle stylisée
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final scale = 1.0 + pulseController.value * 0.03;
              return Transform.scale(scale: scale, child: child);
            },
            child: _VisualIllustration(step: step),
          ),

          const SizedBox(height: 36),

          // Textes et badges
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
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(step.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          step.subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      step.body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Illustrations Interactives Mockup Style ───────────────────────────────────

class _VisualIllustration extends StatelessWidget {
  final _OnboardingStep step;

  const _VisualIllustration({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: _buildMockupContent(step.illustrationKey),
      ),
    );
  }

  Widget _buildMockupContent(String key) {
    switch (key) {
      case 'cours':
        return _buildCourseMockup();
      case 'ai':
        return _buildAiMockup();
      case 'progression':
        return _buildProgressionMockup();
      case 'launch':
        return _buildLaunchMockup();
      case 'welcome':
      default:
        return _buildWelcomeMockup();
    }
  }

  Widget _buildWelcomeMockup() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          alignment: Alignment.center,
          child: const Text('🎓', style: TextStyle(fontSize: 38)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Ngenou Study v2.0',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseMockup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Algorithmique & Code',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notion : Les Variables',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const LinearProgressIndicator(
            value: 0.85,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Exercices facultatifs • Maîtrise 85%',
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildAiMockup() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bulle élève
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Un conseil pour l\'examen ?',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Bulle IA
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Fais 2 notions par jour et garde ta série active ! ✨',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressionMockup() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Flamme Série
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: const Text('🔥', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 6),
            Text(
              '3 Jours',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Série active',
              style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.white70),
            ),
          ],
        ),
        Container(width: 1, height: 60, color: Colors.white24),
        // Score Maîtrise
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: const Text('🏆', style: TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 6),
            Text(
              'Niveau 2',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Apprenant',
              style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLaunchMockup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Missions de départ :',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        _miniMissionRow('1. Ouvrir un 1er cours', true),
        const SizedBox(height: 6),
        _miniMissionRow('2. Poser une question à l\'IA', false),
        const SizedBox(height: 6),
        _miniMissionRow('3. Consulter mon bilan', false),
      ],
    );
  }

  Widget _miniMissionRow(String title, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: done ? const Color(0xFF4ADE80) : Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
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
          width: isActive ? 26 : 7,
          height: 7,
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
        final glow = pulseController.value * 0.25 + 0.1;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLast ? 24 : 26,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: glow),
                  blurRadius: 16 + pulseController.value * 6,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF1E293B),
                    size: 16,
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
