import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';

class DeskHelpSurfaceCard extends StatelessWidget {
  final bool compact;
  final Widget child;

  const DeskHelpSurfaceCard({
    super.key,
    required this.compact,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}
