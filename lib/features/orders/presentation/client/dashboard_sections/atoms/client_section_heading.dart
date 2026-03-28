import 'package:flutter/material.dart';

import 'package:avishu/core/theme/typography.dart';

class ClientSectionHeading extends StatelessWidget {
  final String label;

  const ClientSectionHeading({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));
  }
}
