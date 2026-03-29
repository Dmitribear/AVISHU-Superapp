import 'package:flutter/material.dart';

import '../../../../../../core/theme/typography.dart';

class ProductionSectionLabel extends StatelessWidget {
  final String label;

  const ProductionSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));
  }
}
