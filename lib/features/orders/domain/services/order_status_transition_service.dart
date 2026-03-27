import '../enums/order_status.dart';

class OrderStatusTransitionService {
  static const Map<OrderStatus, Set<OrderStatus>> _allowedTransitions = {
    OrderStatus.newOrder: {OrderStatus.accepted, OrderStatus.cancelled},
    OrderStatus.accepted: {OrderStatus.inProduction, OrderStatus.cancelled},
    OrderStatus.inProduction: {OrderStatus.ready, OrderStatus.cancelled},
    OrderStatus.ready: {OrderStatus.completed},
    OrderStatus.completed: <OrderStatus>{},
    OrderStatus.cancelled: <OrderStatus>{},
  };

  bool canTransition(OrderStatus from, OrderStatus to) {
    return _allowedTransitions[from]?.contains(to) ?? false;
  }

  void validateTransition(OrderStatus from, OrderStatus to) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid order status transition: ${from.value} -> ${to.value}',
      );
    }
  }
}
