import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContextSvgIcon extends StatelessWidget {
  final String assetPath;
  final Color color;
  final double size;
  final bool animate;

  const ContextSvgIcon({
    super.key,
    required this.assetPath,
    required this.color,
    this.size = 48,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (!animate) return icon;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}
