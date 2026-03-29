import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class ProductionAnalyticsTileData {
  final String label;
  final String value;

  const ProductionAnalyticsTileData({required this.label, required this.value});
}

class ProductionAnalyticsTile extends StatelessWidget {
  final ProductionAnalyticsTileData data;

  const ProductionAnalyticsTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.label, style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          Text(data.value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
