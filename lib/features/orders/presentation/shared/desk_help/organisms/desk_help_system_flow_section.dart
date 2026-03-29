import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_section_label.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_surface_card.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/models/desk_help_models.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/molecules/desk_help_flow_tile.dart';

class DeskHelpSystemFlowSection extends StatefulWidget {
  final bool compact;
  final String eyebrow;
  final List<DeskHelpFlowStep> steps;

  const DeskHelpSystemFlowSection({
    super.key,
    required this.compact,
    required this.eyebrow,
    required this.steps,
  });

  @override
  State<DeskHelpSystemFlowSection> createState() =>
      _DeskHelpSystemFlowSectionState();
}

class _DeskHelpSystemFlowSectionState extends State<DeskHelpSystemFlowSection> {
  final Set<int> _expandedIndices = <int>{};

  @override
  Widget build(BuildContext context) {
    return DeskHelpSurfaceCard(
      compact: widget.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeskHelpSectionLabel(label: widget.eyebrow),
          const SizedBox(height: 10),
          ...widget.steps.asMap().entries.map(
            (entry) => DeskHelpFlowTile(
              step: entry.value,
              isExpanded: _expandedIndices.contains(entry.key),
              showDivider: entry.key != widget.steps.length - 1,
              onTap: () {
                setState(() {
                  if (_expandedIndices.contains(entry.key)) {
                    _expandedIndices.remove(entry.key);
                  } else {
                    _expandedIndices.add(entry.key);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
