import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/core/theme/typography.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';

class DeskHelpLauncherCard extends StatelessWidget {
  final bool compact;
  final DeskHelpLauncherAction action;

  const DeskHelpLauncherCard({
    super.key,
    required this.compact,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = action.emphasized
        ? AppColors.black
        : AppColors.surfaceLowest;
    final foregroundColor = action.emphasized
        ? AppColors.white
        : AppColors.black;

    return InkWell(
      onTap: action.onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: AppColors.black),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 42 : 46,
              height: compact ? 42 : 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: action.emphasized
                    ? AppColors.white.withValues(alpha: 0.14)
                    : AppColors.surfaceLow,
                border: Border.all(
                  color: action.emphasized
                      ? AppColors.white.withValues(alpha: 0.28)
                      : AppColors.outlineVariant,
                ),
              ),
              child: Icon(action.icon, color: foregroundColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: foregroundColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: action.emphasized ? AppColors.white : AppColors.black,
                border: Border.all(
                  color: action.emphasized ? AppColors.white : AppColors.black,
                ),
              ),
              child: Text(
                action.actionLabel,
                style: AppTypography.button.copyWith(
                  color: action.emphasized ? AppColors.black : AppColors.white,
                  letterSpacing: compact ? 1.8 : 2.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
