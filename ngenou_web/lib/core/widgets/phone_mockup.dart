import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Maquette de smartphone pour présenter les captures d'écran de l'application
class PhoneMockup extends StatelessWidget {
  final String imagePath;
  final bool isNetwork;
  final double width;
  final double? height;
  final String? caption;

  const PhoneMockup({
    super.key,
    required this.imagePath,
    this.isNetwork = false,
    this.width = 300,
    this.height,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    // Proportions d'un smartphone moderne ~ 9:19.5
    final calculatedHeight = height ?? (width * 2.05);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: calculatedHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF020612),
            borderRadius: BorderRadius.circular(width * 0.12),
            border: Border.all(
              color: const Color(0xFF223254),
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.10),
            child: Stack(
              children: [
                // Image d'écran
                Positioned.fill(
                  child: isNetwork
                      ? CachedNetworkImage(
                          imageUrl: imagePath,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.card,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.cyan,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.card,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: AppColors.card,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                ),

                // Encoche / Haut-parleur du haut (Dynamic Island)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: width * 0.28,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF1E2E52),
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F1A33),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Barre de navigation inférieure (Home indicator)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: width * 0.35,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 12),
          Text(
            caption!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
