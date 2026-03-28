import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/order_panels.dart';

class ClientOrderInfoSection extends StatelessWidget {
  final String title;
  final List<OrderInfoRowData> rows;

  const ClientOrderInfoSection({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return OrderInfoCard(title: title, rows: rows);
  }
}
