import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class DeliveryMapAttribution extends StatelessWidget {
  final String label;

  const DeliveryMapAttribution({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 156),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.code.copyWith(
              color: AppColors.white.withValues(alpha: 0.86),
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }
}
