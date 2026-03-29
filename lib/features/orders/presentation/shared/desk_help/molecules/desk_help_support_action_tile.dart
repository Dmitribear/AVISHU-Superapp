import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/core/theme/typography.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';

class DeskHelpSupportActionTile extends StatelessWidget {
  final DeskHelpSupportAction action;

  const DeskHelpSupportActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.black),
              ),
              child: Text(
                action.actionLabel,
                style: AppTypography.button.copyWith(
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
