import 'package:flutter/material.dart';

/// Utilitaires de réactivité et conteneurs pour Ngenou Web
class Responsive {
  Responsive._();

  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1020.0;
  static const double maxContentWidth = 1200.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static double horizontalPadding(BuildContext context) =>
      isMobile(context) ? 20.0 : 36.0;
}

/// Conteneur centré avec largeur maximale pour les sections du site
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
              ),
          child: child,
        ),
      ),
    );
  }
}
