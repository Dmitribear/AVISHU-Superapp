import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../shared/i18n/app_localization.dart';
import '../atoms/why_avishu_surface_card.dart';

class WhyAvishuClosingSection extends StatelessWidget {
  final AppLanguage language;
  final String title;
  final String statement;

  const WhyAvishuClosingSection({
    super.key,
    required this.language,
    required this.title,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    return WhyAvishuSurfaceCard(
      backgroundColor: AppColors.surfaceLow,
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(language, ru: 'ПОЗИЦИОНИРОВАНИЕ', en: 'POSITIONING'),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(statement, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
