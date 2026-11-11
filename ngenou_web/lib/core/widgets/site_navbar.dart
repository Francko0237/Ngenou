import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'download_button.dart';
import 'responsive_layout.dart';

/// Barre de navigation principale du site public Ngenou
class SiteNavbar extends StatelessWidget implements PreferredSizeWidget {
  final Function(String section)? onSectionSelected;

  const SiteNavbar({super.key, this.onSectionSelected});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  void _handleNav(BuildContext context, String target) {
    if (target.startsWith('#')) {
      final section = target.substring(1);
      final currentRoute = GoRouterState.of(context).uri.toString();
      if (currentRoute != '/') {
        context.go('/');
        Future.delayed(const Duration(milliseconds: 300), () {
          onSectionSelected?.call(section);
        });
      } else {
        onSectionSelected?.call(section);
      }
    } else {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context) || Responsive.isTablet(context);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo & Titre
            InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        color: AppColors.cyan,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ngenou',
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Liens Desktop ou Hamburger Mobile
            if (!isMobile) ...[
              Row(
                children: [
                  _NavLink(
                    title: 'Aperçu',
                    onTap: () => _handleNav(context, '#showcase'),
                  ),
                  _NavLink(
                    title: 'Fonctionnalités',
                    onTap: () => _handleNav(context, '#features'),
                  ),
                  _NavLink(
                    title: 'Nouveautés',
                    onTap: () => _handleNav(context, '/nouveautes'),
                  ),
                  _NavLink(
                    title: 'FAQ',
                    onTap: () => _handleNav(context, '#faq'),
                  ),
                  _NavLink(
                    title: 'Confidentialité & CGU',
                    onTap: () => _handleNav(context, '/confidentialite'),
                  ),
                ],
              ),
              const DownloadButton(isCompact: true),
            ] else ...[
              Row(
                children: [
                  const DownloadButton(isCompact: true),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: AppColors.text),
                    onPressed: () {
                      _openMobileMenu(context);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.phone_iphone_rounded, color: AppColors.cyan),
                title: const Text('Aperçu de l\'application'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleNav(context, '#showcase');
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                title: const Text('Fonctionnalités'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleNav(context, '#features');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: AppColors.cyan),
                title: const Text('Nouveautés & Mises à jour'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleNav(context, '/nouveautes');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.gold),
                title: const Text('FAQ'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleNav(context, '#faq');
                },
              ),
              ListTile(
                leading: const Icon(Icons.policy_rounded, color: AppColors.textMuted),
                title: const Text('Confidentialité & CGU'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleNav(context, '/confidentialite');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavLink({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppColors.cardHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
