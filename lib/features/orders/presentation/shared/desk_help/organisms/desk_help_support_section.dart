import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_section_label.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_surface_card.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/molecules/desk_help_support_action_tile.dart';

class DeskHelpSupportSection extends StatelessWidget {
  final bool compact;
  final String eyebrow;
  final String title;
  final String description;
  final String footerText;
  final List<DeskHelpSupportAction> actions;

  const DeskHelpSupportSection({
    super.key,
    required this.compact,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.footerText,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return DeskHelpSurfaceCard(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeskHelpSectionLabel(label: eyebrow),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          ...actions.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == actions.length - 1 ? 0 : 10,
              ),
              child: DeskHelpSupportActionTile(action: entry.value),
            ),
          ),
          const SizedBox(height: 12),
          Text(footerText, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
