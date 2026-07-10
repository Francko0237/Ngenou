import 'package:flutter/material.dart';

class PremiumLoader extends StatefulWidget {
  final String? customText;
  final List<String>? customLoadingTexts;

  const PremiumLoader({super.key, this.customText, this.customLoadingTexts});

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  int _textIndex = 0;

  late final List<String> _loadingTexts;

  @override
  void initState() {
    super.initState();
    _loadingTexts =
        widget.customLoadingTexts ??
        [
          "Initialisation de l'assistant pédagogique...",
          "Création de la structure du cours...",
          "Rédaction des leçons détaillées...",
          "Conception des QCM d'entraînement...",
          "Vérification de la cohérence globale...",
          "Finalisation du package de cours...",
        ];

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _cycleTexts();
  }

  void _cycleTexts() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _textIndex = (_textIndex + 1) % _loadingTexts.length;
      });
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [primaryColor.withOpacity(0.1), primaryColor],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.grey[50],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.15).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            widget.customText ?? "Génération en cours...",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _loadingTexts[_textIndex],
              key: ValueKey<int>(_textIndex),
              style: TextStyle(
                fontSize: 15,
                color: primaryColor.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
