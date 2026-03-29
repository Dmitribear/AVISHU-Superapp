import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';

class DeskHelpFlowTile extends StatelessWidget {
  final DeskHelpFlowStep step;
  final bool isExpanded;
  final bool showDivider;
  final VoidCallback onTap;

  const DeskHelpFlowTile({
    super.key,
    required this.step,
    required this.isExpanded,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: showDivider
                ? const BorderSide(color: AppColors.outlineVariant)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 22,
                  color: AppColors.black,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 10),
              Text(step.details, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
