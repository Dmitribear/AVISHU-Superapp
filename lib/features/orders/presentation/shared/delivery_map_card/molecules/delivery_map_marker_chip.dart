import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class DeliveryMapMarkerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isHighlighted;

  const DeliveryMapMarkerChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 136),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isHighlighted ? 0.84 : 0.66),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppTypography.eyebrow.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
