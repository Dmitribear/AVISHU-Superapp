import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../shared/i18n/app_localization.dart';
import '../atoms/why_avishu_metric_box.dart';
import '../atoms/why_avishu_surface_card.dart';

class WhyAvishuMetricTileData {
  final String label;
  final String value;

  const WhyAvishuMetricTileData({required this.label, required this.value});
}

class WhyAvishuLiveSummarySection extends StatelessWidget {
  final AppLanguage language;
  final List<WhyAvishuMetricTileData> metrics;

  const WhyAvishuLiveSummarySection({
    super.key,
    required this.language,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return WhyAvishuSurfaceCard(
      backgroundColor: AppColors.surfaceLowest,
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              language,
              ru: 'ЖИВАЯ СВОДКА БИЗНЕСА',
              en: 'LIVE BUSINESS SUMMARY',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 540
                  ? 3
                  : constraints.maxWidth >= 320
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: itemWidth,
                      child: WhyAvishuMetricBox(
                        label: metric.label,
                        value: metric.value,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
