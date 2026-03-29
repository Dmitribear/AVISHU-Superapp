import 'package:flutter/material.dart';

import 'package:avishu/core/theme/typography.dart';

class DeskHelpSectionLabel extends StatelessWidget {
  final String label;

  const DeskHelpSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.eyebrow);
  }
}
