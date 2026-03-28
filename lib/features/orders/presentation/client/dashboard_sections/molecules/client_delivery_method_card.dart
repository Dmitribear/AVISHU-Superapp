import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/core/theme/typography.dart';

class ClientDeliveryMethodCard extends StatelessWidget {
  final String eyebrowLabel;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const ClientDeliveryMethodCard({
    super.key,
    required this.eyebrowLabel,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrowLabel,
              style: AppTypography.eyebrow.copyWith(
                color: isActive ? AppColors.surfaceDim : AppColors.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isActive ? AppColors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
