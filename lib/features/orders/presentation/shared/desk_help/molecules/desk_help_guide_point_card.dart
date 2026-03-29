import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/core/theme/typography.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_surface_card.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';

class DeskHelpGuidePointCard extends StatelessWidget {
  final bool compact;
  final int index;
  final DeskHelpGuidePoint point;

  const DeskHelpGuidePointCard({
    super.key,
    required this.compact,
    required this.index,
    required this.point,
  });

  @override
  Widget build(BuildContext context) {
    return DeskHelpSurfaceCard(
      compact: compact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: AppTypography.code.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  point.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
