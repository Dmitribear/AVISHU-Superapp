import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';

class ProductionSurfaceCard extends StatelessWidget {
  final Widget child;
  final bool compact;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Color borderColor;

  const ProductionSurfaceCard({
    super.key,
    required this.child,
    required this.compact,
    this.onTap,
    this.padding,
    this.color = AppColors.surfaceLowest,
    this.borderColor = AppColors.outlineVariant,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(onTap: onTap, child: content);
  }
}
