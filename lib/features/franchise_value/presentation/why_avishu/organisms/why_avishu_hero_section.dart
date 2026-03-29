import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../shared/i18n/app_localization.dart';
import '../atoms/why_avishu_surface_card.dart';
import '../content/why_avishu_content.dart';

class WhyAvishuHeroSection extends StatelessWidget {
  final AppLanguage language;
  final WhyAvishuContent content;

  const WhyAvishuHeroSection({
    super.key,
    required this.language,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return WhyAvishuSurfaceCard(
      backgroundColor: AppColors.black,
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              language,
              ru: 'ВНУТРЕННИЙ ПРОДУКТОВЫЙ РЕЖИМ',
              en: 'EXECUTIVE PRODUCT VIEW',
            ),
            style: AppTypography.eyebrow.copyWith(color: AppColors.surfaceDim),
          ),
          const SizedBox(height: 18),
          Text(
            content.heroTitle,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Text(
            content.heroStatement,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.outline),
          const SizedBox(height: 14),
          Text(
            content.heroSummary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.surfaceHighest),
          ),
        ],
      ),
    );
  }
}
