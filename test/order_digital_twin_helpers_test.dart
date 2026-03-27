import 'package:avishu/features/auth/domain/user_role.dart';
import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/features/orders/domain/models/order_history_entry.dart';
import 'package:avishu/features/orders/domain/models/order_model.dart';
import 'package:avishu/features/orders/presentation/shared/order_digital_twin_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current stage duration uses the latest matching history entry', () {
    final createdAt = DateTime(2026, 3, 28, 9, 0);
    final acceptedAt = createdAt.add(const Duration(minutes: 10));
    final order = OrderModel(
      id: 'order-1',
      clientId: 'client-1',
      createdAt: createdAt,
      productName: 'Skirt SHE',
      sizeLabel: 'M',
      amount: 30500,
      deliveryMethod: DeliveryMethod.courier,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Dostyk 25',
      apartment: '12',
      paymentMethod: 'card',
      paymentLast4: '4242',
      status: OrderStatus.accepted,
      acceptedAt: acceptedAt,
      lastStatusChangedAt: acceptedAt,
      historyEntries: <OrderHistoryEntry>[
        OrderHistoryEntry(
          id: 'h1',
          orderId: 'order-1',
          fromStatus: null,
          toStatus: OrderStatus.newOrder,
          changedByUserId: 'client-1',
          changedByRole: UserRole.client,
          comment: '',
          createdAt: createdAt,
        ),
        OrderHistoryEntry(
          id: 'h2',
          orderId: 'order-1',
          fromStatus: OrderStatus.newOrder,
          toStatus: OrderStatus.accepted,
          changedByUserId: 'franchisee-1',
          changedByRole: UserRole.franchisee,
          comment: '',
          createdAt: acceptedAt,
        ),
      ],
      timeline: const [],
    );

    expect(
      getOrderCurrentStageDuration(
        order,
        now: createdAt.add(const Duration(minutes: 40)),
      ),
      '30 MIN',
    );
  });

  test('timeline mapping keeps fixed operational stages and active step', () {
    final createdAt = DateTime(2026, 3, 28, 9, 0);
    final acceptedAt = createdAt.add(const Duration(minutes: 15));
    final productionAt = createdAt.add(const Duration(minutes: 45));
    final order = OrderModel(
      id: 'order-2',
      clientId: 'client-2',
      createdAt: createdAt,
      productName: 'Suit LINE',
      sizeLabel: 'L',
      amount: 68200,
      deliveryMethod: DeliveryMethod.pickup,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Esentai Mall',
      apartment: '',
      paymentMethod: 'card',
      paymentLast4: '1111',
      status: OrderStatus.inProduction,
      acceptedAt: acceptedAt,
      lastStatusChangedAt: productionAt,
      historyEntries: <OrderHistoryEntry>[
        OrderHistoryEntry(
          id: 'h1',
          orderId: 'order-2',
          fromStatus: null,
          toStatus: OrderStatus.newOrder,
          changedByUserId: 'client-2',
          changedByRole: UserRole.client,
          comment: '',
          createdAt: createdAt,
        ),
        OrderHistoryEntry(
          id: 'h2',
          orderId: 'order-2',
          fromStatus: OrderStatus.newOrder,
          toStatus: OrderStatus.accepted,
          changedByUserId: 'franchisee-2',
          changedByRole: UserRole.franchisee,
          comment: '',
          createdAt: acceptedAt,
        ),
        OrderHistoryEntry(
          id: 'h3',
          orderId: 'order-2',
          fromStatus: OrderStatus.accepted,
          toStatus: OrderStatus.inProduction,
          changedByUserId: 'factory-2',
          changedByRole: UserRole.production,
          comment: '',
          createdAt: productionAt,
        ),
      ],
      timeline: const [],
    );

    final steps = mapOrderHistoryToTimeline(order);

    expect(steps.length, 5);
    expect(steps[0].label, 'CREATED');
    expect(steps[2].label, 'IN PRODUCTION');
    expect(steps[2].isCurrent, isTrue);
    expect(steps[3].timestamp, isNull);
    expect(getResponsibleLabel(order), 'FACTORY LINE');
  });
}
