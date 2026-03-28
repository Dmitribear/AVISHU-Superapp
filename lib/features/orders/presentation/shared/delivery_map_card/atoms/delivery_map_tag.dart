import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class DeliveryMapTag extends StatelessWidget {
  final String label;
  final bool isFilled;

  const DeliveryMapTag({super.key, required this.label, this.isFilled = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFilled
              ? AppColors.black
              : Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.eyebrow.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
