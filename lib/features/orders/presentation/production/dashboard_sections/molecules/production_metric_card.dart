import 'package:flutter/material.dart';

import '../../../../../../core/theme/typography.dart';
import '../atoms/production_surface_card.dart';

class ProductionMetricCardData {
  final String label;
  final String value;

  const ProductionMetricCardData({required this.label, required this.value});
}

class ProductionMetricCard extends StatelessWidget {
  final ProductionMetricCardData data;
  final bool compact;

  const ProductionMetricCard({
    super.key,
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionSurfaceCard(
      compact: compact,
      child: SizedBox(
        height: compact ? 92 : 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(data.label, style: AppTypography.eyebrow),
            const SizedBox(height: 12),
            Text(data.value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
