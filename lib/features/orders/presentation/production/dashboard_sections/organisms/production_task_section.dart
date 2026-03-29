import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../atoms/production_section_label.dart';
import '../atoms/production_surface_card.dart';
import '../molecules/production_task_card.dart';

class ProductionTaskSection extends StatelessWidget {
  final String sectionLabel;
  final String emptyMessage;
  final bool compact;
  final List<ProductionTaskCardData> tasks;

  const ProductionTaskSection({
    super.key,
    required this.sectionLabel,
    required this.emptyMessage,
    required this.compact,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionSectionLabel(label: sectionLabel),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          ProductionSurfaceCard(
            compact: compact,
            color: AppColors.surfaceLow,
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...tasks.indexed.map((entry) {
            final index = entry.$1;
            final task = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == tasks.length - 1 ? 0 : 12,
              ),
              child: ProductionTaskCard(data: task, compact: compact),
            );
          }),
      ],
    );
  }
}
