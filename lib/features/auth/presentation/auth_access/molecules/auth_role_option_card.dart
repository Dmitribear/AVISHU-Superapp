import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';

class AuthRoleOptionCard extends StatelessWidget {
  final String label;
  final String caption;
  final bool isSelected;
  final VoidCallback onTap;

  const AuthRoleOptionCard({
    super.key,
    required this.label,
    required this.caption,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.button.copyWith(
                      letterSpacing: 3,
                      color: isSelected ? AppColors.white : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.surfaceHighest
                          : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.white : AppColors.black,
                  width: isSelected ? 5 : 1.5,
                ),
                color: isSelected ? AppColors.black : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
