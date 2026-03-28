import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/order_panels.dart';

import 'client_order_info_section.dart';

class ClientCheckoutSummarySection extends StatelessWidget {
  final String title;
  final List<OrderInfoRowData> rows;

  const ClientCheckoutSummarySection({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return ClientOrderInfoSection(title: title, rows: rows);
  }
}
