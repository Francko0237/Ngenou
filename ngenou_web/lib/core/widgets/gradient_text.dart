import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Texte stylisé avec le dégradé officiel Ngenou (bleu -> or)
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = AppColors.brandGradient,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
