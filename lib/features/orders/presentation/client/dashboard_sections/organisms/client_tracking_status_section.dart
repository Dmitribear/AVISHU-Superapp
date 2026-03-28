import 'package:flutter/material.dart';

import 'package:avishu/core/theme/typography.dart';
import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/shared/widgets/avishu_order_tracker.dart';

import '../atoms/client_surface_card.dart';

class ClientTrackingStatusSection extends StatelessWidget {
  final bool compact;
  final String orderLabel;
  final String productName;
  final String roleDescription;
  final OrderStatus status;
  final String statusLine;

  const ClientTrackingStatusSection({
    super.key,
    required this.compact,
    required this.orderLabel,
    required this.productName,
    required this.roleDescription,
    required this.status,
    required this.statusLine,
  });

  @override
  Widget build(BuildContext context) {
    return ClientSurfaceCard(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderLabel, style: AppTypography.eyebrow),
          const SizedBox(height: 12),
          Text(productName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(roleDescription, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          AvishuOrderTracker(status: status),
          const SizedBox(height: 10),
          Text(statusLine, style: AppTypography.code),
        ],
      ),
    );
  }
}
