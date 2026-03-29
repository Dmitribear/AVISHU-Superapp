import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../shared/widgets/avishu_button.dart';
import '../atoms/production_status_badge.dart';
import '../atoms/production_surface_card.dart';

class ProductionStationSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String summary;
  final String roleLabel;
  final String roleValue;
  final bool compact;
  final Widget guideSection;
  final Widget flowSection;
  final Widget supportSection;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String secondaryActionLabel;
  final VoidCallback onSecondaryAction;

  const ProductionStationSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.roleLabel,
    required this.roleValue,
    required this.compact,
    required this.guideSection,
    required this.flowSection,
    required this.supportSection,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionSurfaceCard(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ProductionStatusBadge(label: roleValue, emphasized: true),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        guideSection,
        const SizedBox(height: 12),
        flowSection,
        const SizedBox(height: 12),
        supportSection,
        const SizedBox(height: 12),
        AvishuButton(
          text: primaryActionLabel,
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.arrow_outward,
          onPressed: onPrimaryAction,
        ),
        const SizedBox(height: 12),
        AvishuButton(
          text: secondaryActionLabel,
          expanded: true,
          variant: AvishuButtonVariant.outline,
          icon: Icons.logout,
          onPressed: onSecondaryAction,
        ),
      ],
    );
  }
}
