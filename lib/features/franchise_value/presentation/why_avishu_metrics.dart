import '../../orders/domain/enums/order_status.dart';
import '../../orders/domain/models/order_model.dart';

class WhyAvishuMetrics {
  final int todayOrders;
  final int activeOrders;
  final int inProductionOrders;
  final int readyOrders;
  final String averageTimeToReady;

  const WhyAvishuMetrics({
    required this.todayOrders,
    required this.activeOrders,
    required this.inProductionOrders,
    required this.readyOrders,
    required this.averageTimeToReady,
  });
}

WhyAvishuMetrics deriveWhyAvishuMetrics(
  List<OrderModel> orders, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final todayOrders = orders
      .where((order) => _isSameDay(order.createdAt, currentTime))
      .length;
  final activeOrders = orders
      .where(
        (order) =>
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled,
      )
      .length;
  final inProductionOrders = orders
      .where((order) => order.status == OrderStatus.inProduction)
      .length;
  final readyOrders = orders
      .where((order) => order.status == OrderStatus.ready)
      .length;
  final completedOrReady = orders.where(
    (order) =>
        order.status == OrderStatus.ready ||
        order.status == OrderStatus.completed,
  );

  var totalMinutes = 0;
  var measuredOrders = 0;
  for (final order in completedOrReady) {
    final endAt = order.completedAt ?? order.lastStatusChangedAt;
    final minutes = endAt.difference(order.createdAt).inMinutes;
    if (minutes >= 0) {
      totalMinutes += minutes;
      measuredOrders++;
    }
  }

  final averageTimeToReady = measuredOrders == 0
      ? 'TBD'
      : _formatAverage(
          Duration(minutes: (totalMinutes / measuredOrders).round()),
        );

  return WhyAvishuMetrics(
    todayOrders: todayOrders,
    activeOrders: activeOrders,
    inProductionOrders: inProductionOrders,
    readyOrders: readyOrders,
    averageTimeToReady: averageTimeToReady,
  );
}

String _formatAverage(Duration duration) {
  if (duration.inMinutes < 60) {
    return '${duration.inMinutes} MIN';
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (minutes == 0) {
    return '$hours H';
  }
  return '$hours H $minutes MIN';
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
