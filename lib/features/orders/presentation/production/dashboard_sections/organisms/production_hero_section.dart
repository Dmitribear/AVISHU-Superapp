import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';
import '../atoms/production_surface_card.dart';
import '../molecules/production_metric_card.dart';

class ProductionHeroSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool compact;
  final List<ProductionMetricCardData> metrics;

  const ProductionHeroSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionSurfaceCard(
          compact: compact,
          color: AppColors.black,
          borderColor: AppColors.black,
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.surfaceDim,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.surfaceHighest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 420;
            final itemWidth = isWide
                ? (constraints.maxWidth - 16) / 3
                : (constraints.maxWidth - 8) / 2;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: itemWidth,
                      child: ProductionMetricCard(
                        data: metric,
                        compact: compact,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
