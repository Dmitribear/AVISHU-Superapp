import '../../../../shared/i18n/app_localization.dart';
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

String formatOrderStatus(
  OrderStatus status, {
  AppLanguage language = AppLanguage.english,
}) {
  switch (status) {
    case OrderStatus.newOrder:
      return tr(language, ru: 'НОВЫЙ', en: 'NEW');
    case OrderStatus.accepted:
      return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED');
    case OrderStatus.inProduction:
      return tr(language, ru: 'В ПРОИЗВОДСТВЕ', en: 'IN PRODUCTION');
    case OrderStatus.ready:
      return tr(language, ru: 'ГОТОВ', en: 'READY');
    case OrderStatus.completed:
      return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED');
    case OrderStatus.cancelled:
      return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED');
  }
}

String formatOrderPriority(
  OrderPriority priority, {
  AppLanguage language = AppLanguage.english,
}) {
  switch (priority) {
    case OrderPriority.high:
      return tr(language, ru: 'ВЫСОКИЙ', en: 'HIGH');
    case OrderPriority.normal:
      return tr(language, ru: 'ОБЫЧНЫЙ', en: 'NORMAL');
  }
}

String formatFulfillmentTypeLabel(
  FulfillmentType type, {
  AppLanguage language = AppLanguage.english,
}) {
  switch (type) {
    case FulfillmentType.inStock:
      return tr(language, ru: 'ИЗ НАЛИЧИЯ', en: 'IN STOCK');
    case FulfillmentType.preorder:
      return tr(language, ru: 'ПРЕДЗАКАЗ', en: 'PREORDER');
  }
}

String formatOrderEta(
  DateTime? eta, {
  AppLanguage language = AppLanguage.english,
}) {
  if (eta == null) {
    return tr(language, ru: 'УТОЧНЯЕТСЯ', en: 'TBD');
  }
  return _formatDateTime(eta, language);
}

String formatOrderMetaDate(
  DateTime value, {
  AppLanguage language = AppLanguage.english,
}) {
  return _formatDateTime(value, language);
}

String getOrderCurrentStageDuration(
  OrderModel order, {
  DateTime? now,
  AppLanguage language = AppLanguage.english,
}) {
  final currentTime = now ?? DateTime.now();
  final startedAt = getOrderCurrentStageStartedAt(order);
  final difference = currentTime.difference(startedAt);
  return _formatElapsed(difference, language);
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

String getResponsibleLabel(
  OrderModel order, {
  String? responsibleName,
  AppLanguage language = AppLanguage.english,
}) {
  final normalizedName = responsibleName?.trim();
  if (normalizedName != null && normalizedName.isNotEmpty) {
    return normalizedName.toUpperCase();
  }

  switch (order.status) {
    case OrderStatus.newOrder:
      return tr(language, ru: 'КЛИЕНТ', en: 'CLIENT');
    case OrderStatus.accepted:
      return tr(language, ru: 'ФРАНЧАЙЗ ДЕСК', en: 'FRANCHISE DESK');
    case OrderStatus.inProduction:
      return tr(language, ru: 'ЛИНИЯ ЦЕХА', en: 'FACTORY LINE');
    case OrderStatus.ready:
      return tr(language, ru: 'ВЫДАЧА ФРАНЧАЙЗИ', en: 'FRANCHISE HANDOFF');
    case OrderStatus.completed:
      return tr(language, ru: 'СИСТЕМНАЯ ПЕРЕДАЧА', en: 'SYSTEM HANDOFF');
    case OrderStatus.cancelled:
      return tr(language, ru: 'ОПЕРАЦИОННЫЙ ОТДЕЛ', en: 'OPERATIONS DESK');
  }
}

String getClientDisplayLabel(
  OrderModel order, {
  String? clientName,
  AppLanguage language = AppLanguage.english,
}) {
  final normalizedName = clientName?.trim();
  if (normalizedName != null && normalizedName.isNotEmpty) {
    return normalizedName.toUpperCase();
  }

  final normalizedId = order.clientId.trim();
  if (normalizedId.isEmpty) {
    return tr(language, ru: 'ID КЛИЕНТА УТОЧНЯЕТСЯ', en: 'CLIENT ID TBD');
  }

  final shortId = normalizedId.length > 8
      ? normalizedId.substring(0, 8).toUpperCase()
      : normalizedId.toUpperCase();
  return tr(language, ru: 'ID $shortId', en: 'ID $shortId');
}

List<OrderTwinTimelineStep> mapOrderHistoryToTimeline(
  OrderModel order, {
  AppLanguage language = AppLanguage.english,
}) {
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
          label: _timelineLabel(status, language),
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
        label: tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED'),
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

String _timelineLabel(OrderStatus status, AppLanguage language) {
  switch (status) {
    case OrderStatus.newOrder:
      return tr(language, ru: 'СОЗДАН', en: 'CREATED');
    case OrderStatus.accepted:
      return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED');
    case OrderStatus.inProduction:
      return tr(language, ru: 'В ПРОИЗВОДСТВЕ', en: 'IN PRODUCTION');
    case OrderStatus.ready:
      return tr(language, ru: 'ГОТОВ', en: 'READY');
    case OrderStatus.completed:
      return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED');
    case OrderStatus.cancelled:
      return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED');
  }
}

String _formatElapsed(Duration difference, AppLanguage language) {
  if (difference.inMinutes <= 0) {
    return tr(language, ru: 'ТОЛЬКО ЧТО', en: 'JUST NOW');
  }
  if (difference.inHours < 1) {
    return language == AppLanguage.russian
        ? '${difference.inMinutes} МИН'
        : '${difference.inMinutes} MIN';
  }
  if (difference.inDays < 1) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (language == AppLanguage.russian) {
      return minutes == 0 ? '$hours Ч' : '$hours Ч $minutes МИН';
    }
    return minutes == 0 ? '$hours H' : '$hours H $minutes MIN';
  }

  final days = difference.inDays;
  final hours = difference.inHours.remainder(24);
  if (language == AppLanguage.russian) {
    return hours == 0 ? '$days ДН' : '$days ДН $hours Ч';
  }
  return hours == 0 ? '$days D' : '$days D $hours H';
}

String _formatDateTime(DateTime value, AppLanguage language) {
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day ${localizedMonthShort(language, value.month)} ${value.year} / $hour:$minute';
}
