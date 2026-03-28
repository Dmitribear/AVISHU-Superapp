import 'package:flutter/material.dart';

import 'package:avishu/shared/widgets/avishu_button.dart';

class ClientTrackingActionsRow extends StatelessWidget {
  final String backLabel;
  final VoidCallback onBack;
  final String catalogLabel;
  final VoidCallback onOpenCatalog;

  const ClientTrackingActionsRow({
    super.key,
    required this.backLabel,
    required this.onBack,
    required this.catalogLabel,
    required this.onOpenCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AvishuButton(
            text: backLabel,
            onPressed: onBack,
            variant: AvishuButtonVariant.ghost,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AvishuButton(text: catalogLabel, onPressed: onOpenCatalog),
        ),
      ],
    );
  }
}
