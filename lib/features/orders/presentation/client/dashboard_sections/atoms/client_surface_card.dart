import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';

class ClientSurfaceCard extends StatelessWidget {
  final bool compact;
  final Widget child;
  final VoidCallback? onTap;

  const ClientSurfaceCard({
    super.key,
    required this.compact,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );

    return onTap == null ? card : InkWell(onTap: onTap, child: card);
  }
}
