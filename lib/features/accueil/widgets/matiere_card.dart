import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/course_context_mapper.dart';
import '../../course_builder/manage_custom_course_page.dart';

class MatiereCard extends StatelessWidget {
  final String titre;
  final IconData icon;
  final bool isAvailable;
  final double progression;
  final VoidCallback onTap;
  final bool isCustom;
  final String? matiereId;
  final String? coverImageUrl;
  final Color? couleur;

  const MatiereCard({
    super.key,
    required this.titre,
    required this.icon,
    required this.isAvailable,
    required this.progression,
    required this.onTap,
    this.isCustom = false,
    this.matiereId,
    this.coverImageUrl,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final cardCouleur = couleur ?? primary;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.6,
      child: Container(
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
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isAvailable ? onTap : null,
            onLongPress: isCustom && matiereId != null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManageCustomCoursePage(matiereId: matiereId!),
                      ),
                    )
                : null,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Visuel haut : Image de couverture ou SVG de fallback ───
                    Expanded(
                      flex: 55,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(19),
                        ),
                        child: _buildCourseCoverWidget(
                          coverImageUrl: coverImageUrl,
                          titre: titre,
                          icon: icon,
                          couleur: cardCouleur,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    // ─── Contenu bas : Titre et Progression ───
                    Expanded(
                      flex: 45,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              titre,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF15151C),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isAvailable && progression > 0) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Progression',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '${progression.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: progression == 100
                                              ? const Color(0xFF2ECC71)
                                              : cardCouleur,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progression / 100,
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.06),
                                      valueColor: AlwaysStoppedAnimation(
                                        progression == 100
                                            ? const Color(0xFF2ECC71)
                                            : cardCouleur,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isAvailable) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 13,
                                    color: cardCouleur,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Commencer',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: cardCouleur,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Bientôt disponible',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Badge "Créé par vous" pour les cours personnalisés
                if (isCustom)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Perso',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCoverWidget({
    required String? coverImageUrl,
    required String titre,
    required IconData icon,
    required Color couleur,
    required bool isDark,
  }) {
    if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty) {
      final cover = coverImageUrl.trim();
      if (cover.startsWith('data:image')) {
        try {
          final commaIdx = cover.indexOf(',');
          final base64Str =
              commaIdx != -1 ? cover.substring(commaIdx + 1) : cover;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                _buildCourseSvgFallback(titre, icon, couleur, isDark),
          );
        } catch (_) {}
      } else if (cover.startsWith('http')) {
        return Image.network(
          cover,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              _buildCourseSvgFallback(titre, icon, couleur, isDark),
        );
      } else if (cover.startsWith('assets/')) {
        return Image.asset(
          cover,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              _buildCourseSvgFallback(titre, icon, couleur, isDark),
        );
      } else {
        return Image.file(
          File(cover),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              _buildCourseSvgFallback(titre, icon, couleur, isDark),
        );
      }
    }

    return _buildCourseSvgFallback(titre, icon, couleur, isDark);
  }

  Widget _buildCourseSvgFallback(
    String titre,
    IconData icon,
    Color couleur,
    bool isDark,
  ) {
    final svgAsset = CourseContextMapper.getSvgForCourse(titre, icon);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            couleur.withValues(alpha: isDark ? 0.35 : 0.22),
            couleur.withValues(alpha: isDark ? 0.15 : 0.08),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        svgAsset,
        width: 38,
        height: 38,
        colorFilter: ColorFilter.mode(
          isDark
              ? couleur
              : (couleur.computeLuminance() > 0.6
                  ? const Color(0xFF15151C)
                  : couleur),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
