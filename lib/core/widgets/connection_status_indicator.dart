import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final isOnline = connectivity.hasConnection;

    final color = isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);

    return Tooltip(
      message: isOnline ? "Connecté à Internet" : "Mode Hors-ligne actif",
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          // Opacité qui descend doucement de 1.0 à 0.45 et remonte — subtil
          final opacity = 0.45 + (_pulseController.value * 0.55);
          // Halo très discret, juste un léger reflet
          final glowOpacity = _pulseController.value * 0.25;

          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowOpacity),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
