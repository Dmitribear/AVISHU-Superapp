import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../atoms/why_avishu_surface_card.dart';
import '../content/why_avishu_content.dart';

class WhyAvishuValueCard extends StatelessWidget {
  final WhyAvishuValueBlock block;

  const WhyAvishuValueCard({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return WhyAvishuSurfaceCard(
      backgroundColor: AppColors.surfaceLowest,
      borderColor: AppColors.outlineVariant,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: AppTypography.button),
          const SizedBox(height: 10),
          Text(
            block.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
