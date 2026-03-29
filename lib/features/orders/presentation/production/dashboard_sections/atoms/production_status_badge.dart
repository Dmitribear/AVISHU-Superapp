import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class ProductionStatusBadge extends StatelessWidget {
  final String label;
  final bool emphasized;

  const ProductionStatusBadge({
    super.key,
    required this.label,
    this.emphasized = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = emphasized ? AppColors.black : AppColors.surfaceLow;
    final foreground = emphasized ? AppColors.white : AppColors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: emphasized ? AppColors.black : AppColors.outlineVariant,
        ),
      ),
      child: Text(label, style: AppTypography.code.copyWith(color: foreground)),
    );
  }
}
