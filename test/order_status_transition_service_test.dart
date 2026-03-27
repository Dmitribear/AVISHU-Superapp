import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/features/orders/domain/services/order_status_transition_service.dart';

void main() {
  final service = OrderStatusTransitionService();

  test('allows only supported order status transitions', () {
    expect(
      service.canTransition(OrderStatus.newOrder, OrderStatus.accepted),
      isTrue,
    );
    expect(
      service.canTransition(OrderStatus.accepted, OrderStatus.inProduction),
      isTrue,
    );
    expect(
      service.canTransition(OrderStatus.inProduction, OrderStatus.ready),
      isTrue,
    );
    expect(
      service.canTransition(OrderStatus.ready, OrderStatus.completed),
      isTrue,
    );
    expect(
      service.canTransition(OrderStatus.ready, OrderStatus.accepted),
      isFalse,
    );
    expect(
      service.canTransition(OrderStatus.completed, OrderStatus.cancelled),
      isFalse,
    );
  });

  test('throws on invalid transitions', () {
    expect(
      () => service.validateTransition(OrderStatus.newOrder, OrderStatus.ready),
      throwsStateError,
    );
  });
}
