import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_section_label.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_surface_card.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/molecules/desk_help_guide_point_card.dart';

class DeskHelpGuideSection extends StatelessWidget {
  final bool compact;
  final String eyebrow;
  final String title;
  final String description;
  final List<DeskHelpGuidePoint> points;

  const DeskHelpGuideSection({
    super.key,
    required this.compact,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeskHelpSurfaceCard(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeskHelpSectionLabel(label: eyebrow),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...points.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == points.length - 1 ? 0 : 12,
            ),
            child: DeskHelpGuidePointCard(
              compact: compact,
              index: entry.key,
              point: entry.value,
            ),
          ),
        ),
      ],
    );
  }
}
