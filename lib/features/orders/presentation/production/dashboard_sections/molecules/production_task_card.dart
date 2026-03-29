import 'package:flutter/material.dart';

import '../../../../../../core/theme/typography.dart';
import '../atoms/production_info_chip.dart';
import '../atoms/production_status_badge.dart';
import '../atoms/production_surface_card.dart';

class ProductionTaskCardData {
  final String orderLabel;
  final String statusLabel;
  final String productName;
  final List<String> facts;
  final String footerLabel;
  final VoidCallback onTap;

  const ProductionTaskCardData({
    required this.orderLabel,
    required this.statusLabel,
    required this.productName,
    required this.facts,
    required this.footerLabel,
    required this.onTap,
  });
}

class ProductionTaskCard extends StatelessWidget {
  final ProductionTaskCardData data;
  final bool compact;

  const ProductionTaskCard({
    super.key,
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final visibleFacts = data.facts
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return ProductionSurfaceCard(
      compact: compact,
      onTap: data.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(data.orderLabel, style: AppTypography.eyebrow),
              ),
              const SizedBox(width: 12),
              Flexible(child: ProductionStatusBadge(label: data.statusLabel)),
            ],
          ),
          const SizedBox(height: 16),
          Text(data.productName, style: Theme.of(context).textTheme.titleLarge),
          if (visibleFacts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleFacts
                  .map((fact) => ProductionInfoChip(label: fact))
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(data.footerLabel, style: AppTypography.button),
              ),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
