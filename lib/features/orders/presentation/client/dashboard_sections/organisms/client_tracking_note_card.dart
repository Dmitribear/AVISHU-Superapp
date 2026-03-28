import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/order_panels.dart';

class ClientTrackingNoteCard extends StatelessWidget {
  final String title;
  final String label;
  final String value;

  const ClientTrackingNoteCard({
    super.key,
    required this.title,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return OrderInfoCard(
      title: title,
      rows: [OrderInfoRowData(label: label, value: value)],
    );
  }
}
