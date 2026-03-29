import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

enum AvishuButtonVariant { filled, outline, ghost }

class AvishuButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AvishuButtonVariant variant;
  final bool expanded;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final double? height;

  const AvishuButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AvishuButtonVariant.outline,
    this.expanded = false,
    this.icon,
    this.padding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = variant == AvishuButtonVariant.filled
        ? AppColors.white
        : AppColors.black;
    final label = LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth =
            constraints.hasBoundedWidth && constraints.maxWidth < 190;
        final labelStyle = AppTypography.button.copyWith(
          color: labelColor,
          letterSpacing: compactWidth ? 1.8 : 2.8,
        );
        final labelText = Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: compactWidth ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        );

        return Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (constraints.hasBoundedWidth)
              Flexible(child: labelText)
            else
              labelText,
            if (icon != null) ...[
              SizedBox(width: compactWidth ? 8 : 10),
              Icon(icon, size: 18, color: labelColor),
            ],
          ],
        );
      },
    );

    final resolvedPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
    final resolvedMinimumSize = height == null ? null : Size(0, height!);

    Widget button;
    switch (variant) {
      case AvishuButtonVariant.filled:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: resolvedMinimumSize,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: label,
        );
      case AvishuButtonVariant.ghost:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: resolvedMinimumSize,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: label,
        );
      case AvishuButtonVariant.outline:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.black,
            backgroundColor: AppColors.surfaceLowest,
            side: const BorderSide(color: AppColors.black, width: 1),
            padding: resolvedPadding,
            minimumSize: resolvedMinimumSize,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: label,
        );
    }

    if (!expanded) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
