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

  const AvishuButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AvishuButtonVariant.outline,
    this.expanded = false,
    this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: variant == AvishuButtonVariant.filled
                ? AppColors.white
                : AppColors.black,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 10),
          Icon(
            icon,
            size: 18,
            color: variant == AvishuButtonVariant.filled
                ? AppColors.white
                : AppColors.black,
          ),
        ],
      ],
    );

    final resolvedPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 18);

    Widget button;
    switch (variant) {
      case AvishuButtonVariant.filled:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: resolvedPadding,
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
