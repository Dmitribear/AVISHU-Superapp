import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../shared/i18n/app_localization.dart';
import '../atoms/why_avishu_surface_card.dart';
import '../molecules/why_avishu_flow_step_row.dart';

class WhyAvishuFlowSection extends StatelessWidget {
  final AppLanguage language;
  final List<String> flowLabels;

  const WhyAvishuFlowSection({
    super.key,
    required this.language,
    required this.flowLabels,
  });

  @override
  Widget build(BuildContext context) {
    return WhyAvishuSurfaceCard(
      backgroundColor: AppColors.surfaceLowest,
      borderColor: AppColors.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(language, ru: 'СИСТЕМНЫЙ ПОТОК', en: 'SYSTEM FLOW'),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 14),
          for (final entry in flowLabels.indexed)
            WhyAvishuFlowStepRow(
              label: entry.$2,
              isLast: entry.$1 == flowLabels.length - 1,
            ),
        ],
      ),
    );
  }
}
