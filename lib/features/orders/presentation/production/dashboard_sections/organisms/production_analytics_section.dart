import 'package:flutter/material.dart';

import '../atoms/production_section_label.dart';
import '../atoms/production_surface_card.dart';
import '../molecules/production_analytics_tile.dart';

class ProductionTailoringFact {
  final String productName;
  final String durationLabel;
  final String orderCountLabel;

  const ProductionTailoringFact({
    required this.productName,
    required this.durationLabel,
    required this.orderCountLabel,
  });
}

class ProductionAnalyticsSection extends StatelessWidget {
  final String sectionLabel;
  final String title;
  final String summary;
  final String footerText;
  final String slowSectionLabel;
  final bool compact;
  final List<ProductionAnalyticsTileData> metrics;
  final List<ProductionTailoringFact> slowProducts;

  const ProductionAnalyticsSection({
    super.key,
    required this.sectionLabel,
    required this.title,
    required this.summary,
    required this.footerText,
    required this.slowSectionLabel,
    required this.compact,
    required this.metrics,
    required this.slowProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionSurfaceCard(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductionSectionLabel(label: sectionLabel),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(summary, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: metrics
                        .map(
                          (metric) => SizedBox(
                            width: itemWidth,
                            child: ProductionAnalyticsTile(data: metric),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(footerText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (slowProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProductionSurfaceCard(
            compact: compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductionSectionLabel(label: slowSectionLabel),
                const SizedBox(height: 14),
                ...slowProducts.indexed.map((entry) {
                  final index = entry.$1;
                  final fact = entry.$2;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == slowProducts.length - 1 ? 0 : 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            fact.productName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fact.durationLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fact.orderCountLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
