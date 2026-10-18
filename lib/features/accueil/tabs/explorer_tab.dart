import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExplorerTab extends StatelessWidget {
  const ExplorerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hPad = w > 1200 ? w * 0.08 : w > 700 ? w * 0.05 : 18.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── En-tête de section ─────────────────────────────────────────
              Text(
                'Explorer & Créer 🪄',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF15151C),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Catalogue partagé, studio de création IA et extensions interactives',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // ─── 1. Catalogue de cours publics ─────────────────────────────
              _buildFeatureCard(
                context: context,
                title: 'Catalogue de Cours Publics',
                badgeText: 'Partage',
                badgeColor: const Color(0xFF2ECC71),
                description:
                    'Explorez et inscrivez-vous aux cours créés par les professeurs certifiés et la communauté.',
                icon: Icons.public_rounded,
                gradientColors: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                actionLabel: 'Explorer le catalogue',
                onTap: () => context.push('/catalogue'),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ─── 2. Créateur de cours IA ────────────────────────────────────
              _buildFeatureCard(
                context: context,
                title: 'Créateur de Cours IA',
                badgeText: 'Studio IA',
                badgeColor: const Color(0xFFF59E0B),
                description:
                    'Un assistant intelligent génère un programme complet de leçons, cours et quiz sur mesure.',
                icon: Icons.auto_awesome_rounded,
                gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                actionLabel: 'Créer un cours',
                onTap: () => context.push('/course-builder'),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ─── 3. Boîte à Outils & Extensions ─────────────────────────────
              _buildFeatureCard(
                context: context,
                title: 'Boîte à Outils & Extensions',
                badgeText: 'Interactif',
                badgeColor: const Color(0xFFEC4899),
                description:
                    'Visualiseur de fractions, tableau interactif de conversion des unités, nombres relatifs...',
                icon: Icons.extension_rounded,
                gradientColors: const [Color(0xFFE11D48), Color(0xFFF43F5E)],
                actionLabel: 'Ouvrir les extensions',
                onTap: () => context.push('/extensions'),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ─── 4. Statistiques & Progression ─────────────────────────────
              _buildFeatureCard(
                context: context,
                title: 'Bilan & Progression Détaillée',
                badgeText: 'Statistiques',
                badgeColor: const Color(0xFF3B82F6),
                description:
                    'Consultez vos courbes d\'apprentissage, scores récents et badges débloqués.',
                icon: Icons.insights_rounded,
                gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                actionLabel: 'Voir mes progrès',
                onTap: () => context.push('/progression'),
                isDark: isDark,
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required IconData icon,
    required List<Color> gradientColors,
    required String actionLabel,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF15151C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: gradientColors[0],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: gradientColors[0],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
