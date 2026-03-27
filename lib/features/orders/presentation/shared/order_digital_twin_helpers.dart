import '../../domain/enums/fulfillment_type.dart';
import '../../domain/enums/order_priority.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/order_history_entry.dart';
import '../../domain/models/order_model.dart';

class OrderTwinTimelineStep {
  final OrderStatus status;
  final String label;
  final DateTime? timestamp;
  final bool isReached;
  final bool isCurrent;

  const OrderTwinTimelineStep({
    required this.status,
    required this.label,
    required this.timestamp,
    required this.isReached,
    required this.isCurrent,
  });
}

String formatOrderStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.newOrder:
      return 'NEW';
    case OrderStatus.accepted:
      return 'ACCEPTED';
    case OrderStatus.inProduction:
      return 'IN PRODUCTION';
    case OrderStatus.ready:
      return 'READY';
    case OrderStatus.completed:
      return 'COMPLETED';
    case OrderStatus.cancelled:
      return 'CANCELLED';
  }
}

String formatOrderPriority(OrderPriority priority) {
  switch (priority) {
    case OrderPriority.high:
      return 'HIGH';
    case OrderPriority.normal:
      return 'NORMAL';
  }
}

String formatFulfillmentTypeLabel(FulfillmentType type) {
  switch (type) {
    case FulfillmentType.inStock:
      return 'IN STOCK';
    case FulfillmentType.preorder:
      return 'PREORDER';
  }
}

String formatOrderEta(DateTime? eta) {
  if (eta == null) {
    return 'TBD';
  }
  return _formatDateTime(eta);
}

String formatOrderMetaDate(DateTime value) {
  return _formatDateTime(value);
}

String getOrderCurrentStageDuration(OrderModel order, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final startedAt = getOrderCurrentStageStartedAt(order);
  final difference = currentTime.difference(startedAt);
  return _formatElapsed(difference);
}

DateTime getOrderCurrentStageStartedAt(OrderModel order) {
  final historyEntry = _latestHistoryForStatus(order, order.status);
  if (historyEntry != null) {
    return historyEntry.createdAt;
  }

  switch (order.status) {
    case OrderStatus.newOrder:
      return order.createdAt;
    case OrderStatus.accepted:
      return order.acceptedAt ?? order.lastStatusChangedAt;
    case OrderStatus.inProduction:
    case OrderStatus.ready:
    case OrderStatus.completed:
    case OrderStatus.cancelled:
      return order.lastStatusChangedAt;
  }
}

String getResponsibleLabel(OrderModel order, {String? responsibleName}) {
  final normalizedName = responsibleName?.trim();
  if (normalizedName != null && normalizedName.isNotEmpty) {
    return normalizedName.toUpperCase();
  }

  switch (order.status) {
    case OrderStatus.newOrder:
      return 'CLIENT';
    case OrderStatus.accepted:
      return 'FRANCHISE DESK';
    case OrderStatus.inProduction:
      return 'FACTORY LINE';
    case OrderStatus.ready:
      return 'FRANCHISE HANDOFF';
    case OrderStatus.completed:
      return 'SYSTEM HANDOFF';
    case OrderStatus.cancelled:
      return 'OPERATIONS DESK';
  }
}

String getClientDisplayLabel(OrderModel order, {String? clientName}) {
  final normalizedName = clientName?.trim();
  if (normalizedName != null && normalizedName.isNotEmpty) {
    return normalizedName.toUpperCase();
  }

  final normalizedId = order.clientId.trim();
  if (normalizedId.isEmpty) {
    return 'CLIENT ID TBD';
  }

  final shortId = normalizedId.length > 8
      ? normalizedId.substring(0, 8).toUpperCase()
      : normalizedId.toUpperCase();
  return 'ID $shortId';
}

List<OrderTwinTimelineStep> mapOrderHistoryToTimeline(OrderModel order) {
  const stages = <OrderStatus>[
    OrderStatus.newOrder,
    OrderStatus.accepted,
    OrderStatus.inProduction,
    OrderStatus.ready,
    OrderStatus.completed,
  ];

  final reachedStatuses = order.history.map((entry) => entry.toStatus).toSet();
  final steps = stages
      .map(
        (status) => OrderTwinTimelineStep(
          status: status,
          label: _timelineLabel(status),
          timestamp: _timestampForStatus(order, status),
          isReached:
              status == OrderStatus.newOrder ||
              reachedStatuses.contains(status),
          isCurrent: order.status == status,
        ),
      )
      .toList();

  if (order.status == OrderStatus.cancelled) {
    steps.add(
      OrderTwinTimelineStep(
        status: OrderStatus.cancelled,
        label: 'CANCELLED',
        timestamp:
            _timestampForStatus(order, OrderStatus.cancelled) ??
            order.lastStatusChangedAt,
        isReached: true,
        isCurrent: true,
      ),
    );
  }

  return steps;
}

DateTime? _timestampForStatus(OrderModel order, OrderStatus status) {
  final historyEntry = _latestHistoryForStatus(order, status);
  if (historyEntry != null) {
    return historyEntry.createdAt;
  }

  switch (status) {
    case OrderStatus.newOrder:
      return order.createdAt;
    case OrderStatus.accepted:
      return order.acceptedAt;
    case OrderStatus.inProduction:
    case OrderStatus.ready:
    case OrderStatus.cancelled:
      return order.status == status ? order.lastStatusChangedAt : null;
    case OrderStatus.completed:
      return order.completedAt;
  }
}

OrderHistoryEntry? _latestHistoryForStatus(
  OrderModel order,
  OrderStatus status,
) {
  for (final entry in order.history.reversed) {
    if (entry.toStatus == status) {
      return entry;
    }
  }
  return null;
}

String _timelineLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.newOrder:
      return 'CREATED';
    case OrderStatus.accepted:
      return 'ACCEPTED';
    case OrderStatus.inProduction:
      return 'IN PRODUCTION';
    case OrderStatus.ready:
      return 'READY';
    case OrderStatus.completed:
      return 'COMPLETED';
    case OrderStatus.cancelled:
      return 'CANCELLED';
  }
}

String _formatElapsed(Duration difference) {
  if (difference.inMinutes <= 0) {
    return 'JUST NOW';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} MIN';
  }
  if (difference.inDays < 1) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return minutes == 0 ? '$hours H' : '$hours H $minutes MIN';
  }

  final days = difference.inDays;
  final hours = difference.inHours.remainder(24);
  return hours == 0 ? '$days D' : '$days D $hours H';
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day ${_monthCode(value.month)} ${value.year} / $hour:$minute';
}

String _monthCode(int month) {
  const codes = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return codes[month - 1];
}
