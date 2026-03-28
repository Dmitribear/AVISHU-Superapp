import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/delivery_method.dart';
import '../enums/order_status.dart';
import '../models/order_model.dart';

final orderAnalyticsServiceProvider = Provider<OrderAnalyticsService>(
  (ref) => const OrderAnalyticsService(),
);

class OrderAnalyticsService {
  const OrderAnalyticsService();

  FranchiseeAnalyticsSnapshot buildFranchiseeSnapshot(
    List<OrderModel> orders, {
    DateTime? now,
  }) {
    final relevantOrders = orders
        .where((order) => order.status != OrderStatus.cancelled)
        .toList();
    final activeClients = relevantOrders
        .map((order) => order.clientId)
        .where((clientId) => clientId.trim().isNotEmpty)
        .toSet();
    final repeatClients = _repeatClients(relevantOrders);
    final topProduct = _topProduct(relevantOrders);

    return FranchiseeAnalyticsSnapshot(
      uniqueClients: activeClients.length,
      repeatClients: repeatClients,
      averageOrderValue: _averageAmount(
        relevantOrders.map((order) => order.totalAmount),
      ),
      averageAcceptanceTime: _averageDuration(
        relevantOrders
            .map(
              (order) => _durationBetween(
                order.createdAt,
                _statusTimestamp(order, OrderStatus.accepted),
              ),
            )
            .whereType<Duration>(),
      ),
      averageCourierDeliveryTime: _averageDuration(
        relevantOrders
            .where((order) => order.deliveryMethod == DeliveryMethod.courier)
            .map(
              (order) => _durationBetween(
                _statusTimestamp(order, OrderStatus.ready),
                order.completedAt,
              ),
            )
            .whereType<Duration>(),
      ),
      topProductName: topProduct?.name,
      topProductCount: topProduct?.count ?? 0,
      completedOrders: relevantOrders
          .where((order) => order.status == OrderStatus.completed)
          .length,
    );
  }

  ProductionAnalyticsSnapshot buildProductionSnapshot(
    List<OrderModel> orders, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final relevantOrders = orders
        .where((order) => order.status != OrderStatus.cancelled)
        .toList();
    final productMetrics = _productTailoringMetrics(relevantOrders);

    return ProductionAnalyticsSnapshot(
      averageQueueToStartTime: _averageDuration(
        relevantOrders
            .map(
              (order) => _durationBetween(
                _statusTimestamp(order, OrderStatus.accepted),
                _statusTimestamp(order, OrderStatus.inProduction),
              ),
            )
            .whereType<Duration>(),
      ),
      averageTailoringTime: _averageDuration(
        relevantOrders
            .map(
              (order) => _durationBetween(
                _statusTimestamp(order, OrderStatus.inProduction),
                _statusTimestamp(order, OrderStatus.ready),
              ),
            )
            .whereType<Duration>(),
      ),
      averageCourierDeliveryTime: _averageDuration(
        relevantOrders
            .where((order) => order.deliveryMethod == DeliveryMethod.courier)
            .map(
              (order) => _durationBetween(
                _statusTimestamp(order, OrderStatus.ready),
                order.completedAt,
              ),
            )
            .whereType<Duration>(),
      ),
      readyToday: relevantOrders
          .where(
            (order) => _isSameDay(
              _statusTimestamp(order, OrderStatus.ready),
              currentTime,
            ),
          )
          .length,
      overdueOrders: relevantOrders
          .where(
            (order) =>
                order.estimatedReadyAt != null &&
                order.estimatedReadyAt!.isBefore(currentTime) &&
                order.status != OrderStatus.ready &&
                order.status != OrderStatus.completed,
          )
          .length,
      productMetrics: productMetrics,
    );
  }

  List<ProductTailoringMetric> _productTailoringMetrics(
    List<OrderModel> orders,
  ) {
    final grouped = <String, List<Duration>>{};

    for (final order in orders) {
      final tailoringDuration = _durationBetween(
        _statusTimestamp(order, OrderStatus.inProduction),
        _statusTimestamp(order, OrderStatus.ready),
      );
      if (tailoringDuration == null) {
        continue;
      }

      grouped
          .putIfAbsent(_productGroupName(order.productName), () => <Duration>[])
          .add(tailoringDuration);
    }

    final metrics = grouped.entries.map((entry) {
      return ProductTailoringMetric(
        productName: entry.key,
        orderCount: entry.value.length,
        averageTailoringTime: _averageDuration(entry.value),
      );
    }).toList();

    metrics.sort((a, b) {
      final durationCompare = b.averageTailoringTime.compareTo(
        a.averageTailoringTime,
      );
      if (durationCompare != 0) {
        return durationCompare;
      }
      return b.orderCount.compareTo(a.orderCount);
    });
    return metrics;
  }

  int _repeatClients(List<OrderModel> orders) {
    final counts = <String, int>{};
    for (final order in orders) {
      final clientId = order.clientId.trim();
      if (clientId.isEmpty) {
        continue;
      }
      counts.update(clientId, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts.values.where((count) => count > 1).length;
  }

  _ProductAggregate? _topProduct(List<OrderModel> orders) {
    final counts = <String, int>{};
    for (final order in orders) {
      final productName = _productGroupName(order.productName);
      counts.update(productName, (value) => value + 1, ifAbsent: () => 1);
    }

    if (counts.isEmpty) {
      return null;
    }

    final topEntry = counts.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );
    return _ProductAggregate(name: topEntry.key, count: topEntry.value);
  }

  String _productGroupName(String productName) {
    final separatorIndex = productName.indexOf(' / ');
    if (separatorIndex <= 0) {
      return productName.trim();
    }
    return productName.substring(0, separatorIndex).trim();
  }

  Duration? _durationBetween(DateTime? start, DateTime? end) {
    if (start == null || end == null || end.isBefore(start)) {
      return null;
    }
    return end.difference(start);
  }

  DateTime? _statusTimestamp(OrderModel order, OrderStatus status) {
    switch (status) {
      case OrderStatus.newOrder:
        return order.createdAt;
      case OrderStatus.accepted:
        return order.acceptedAt ?? _historyTimestamp(order, status);
      case OrderStatus.inProduction:
      case OrderStatus.ready:
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return _historyTimestamp(order, status) ??
            (order.status == status ? order.lastStatusChangedAt : null);
    }
  }

  DateTime? _historyTimestamp(OrderModel order, OrderStatus status) {
    for (final entry in order.history.reversed) {
      if (entry.toStatus == status) {
        return entry.createdAt;
      }
    }
    if (status == OrderStatus.completed) {
      return order.completedAt;
    }
    return null;
  }

  Duration _averageDuration(Iterable<Duration> values) {
    final durations = values.toList();
    if (durations.isEmpty) {
      return Duration.zero;
    }

    final totalMicroseconds = durations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMicroseconds,
    );
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }

  double _averageAmount(Iterable<double> values) {
    final amounts = values.toList();
    if (amounts.isEmpty) {
      return 0;
    }
    final total = amounts.fold<double>(0, (sum, value) => sum + value);
    return total / amounts.length;
  }

  bool _isSameDay(DateTime? value, DateTime other) {
    if (value == null) {
      return false;
    }
    return value.year == other.year &&
        value.month == other.month &&
        value.day == other.day;
  }
}

class FranchiseeAnalyticsSnapshot {
  final int uniqueClients;
  final int repeatClients;
  final double averageOrderValue;
  final Duration averageAcceptanceTime;
  final Duration averageCourierDeliveryTime;
  final String? topProductName;
  final int topProductCount;
  final int completedOrders;

  const FranchiseeAnalyticsSnapshot({
    required this.uniqueClients,
    required this.repeatClients,
    required this.averageOrderValue,
    required this.averageAcceptanceTime,
    required this.averageCourierDeliveryTime,
    required this.topProductName,
    required this.topProductCount,
    required this.completedOrders,
  });
}

class ProductionAnalyticsSnapshot {
  final Duration averageQueueToStartTime;
  final Duration averageTailoringTime;
  final Duration averageCourierDeliveryTime;
  final int readyToday;
  final int overdueOrders;
  final List<ProductTailoringMetric> productMetrics;

  const ProductionAnalyticsSnapshot({
    required this.averageQueueToStartTime,
    required this.averageTailoringTime,
    required this.averageCourierDeliveryTime,
    required this.readyToday,
    required this.overdueOrders,
    required this.productMetrics,
  });
}

class ProductTailoringMetric {
  final String productName;
  final int orderCount;
  final Duration averageTailoringTime;

  const ProductTailoringMetric({
    required this.productName,
    required this.orderCount,
    required this.averageTailoringTime,
  });
}

class _ProductAggregate {
  final String name;
  final int count;

  const _ProductAggregate({required this.name, required this.count});
}
