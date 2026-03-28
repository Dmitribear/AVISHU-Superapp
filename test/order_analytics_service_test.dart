import 'package:avishu/features/auth/domain/user_role.dart';
import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/features/orders/domain/models/order_history_entry.dart';
import 'package:avishu/features/orders/domain/models/order_model.dart';
import 'package:avishu/features/orders/domain/services/order_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildFranchiseeSnapshot summarizes clients, value and delivery pace',
    () {
      final service = OrderAnalyticsService();
      final now = DateTime(2026, 3, 28, 18);
      final orders = _sampleOrders(now);

      final snapshot = service.buildFranchiseeSnapshot(orders, now: now);

      expect(snapshot.uniqueClients, 3);
      expect(snapshot.repeatClients, 1);
      expect(snapshot.averageOrderValue, 75000);
      expect(snapshot.averageAcceptanceTime, const Duration(minutes: 45));
      expect(snapshot.averageCourierDeliveryTime, const Duration(hours: 6));
      expect(snapshot.topProductName, 'Dress');
      expect(snapshot.topProductCount, 2);
      expect(snapshot.completedOrders, 2);
    },
  );

  test(
    'buildProductionSnapshot summarizes tailoring pace and overdue work',
    () {
      final service = OrderAnalyticsService();
      final now = DateTime(2026, 3, 28, 18);
      final orders = _sampleOrders(now);

      final snapshot = service.buildProductionSnapshot(orders, now: now);

      expect(snapshot.averageQueueToStartTime, const Duration(minutes: 75));
      expect(snapshot.averageTailoringTime, const Duration(hours: 18));
      expect(snapshot.averageCourierDeliveryTime, const Duration(hours: 6));
      expect(snapshot.readyToday, 3);
      expect(snapshot.overdueOrders, 1);
      expect(snapshot.productMetrics.first.productName, 'Dress');
      expect(snapshot.productMetrics.first.orderCount, 2);
      expect(
        snapshot.productMetrics.first.averageTailoringTime,
        const Duration(hours: 25),
      );
    },
  );
}

List<OrderModel> _sampleOrders(DateTime now) {
  final base = DateTime(2026, 3, 27, 9);

  return <OrderModel>[
    _buildOrder(
      id: 'order-1',
      clientId: 'client-1',
      productName: 'Dress / Black',
      amount: 60000,
      deliveryMethod: DeliveryMethod.courier,
      status: OrderStatus.completed,
      createdAt: base,
      acceptedAt: base.add(const Duration(hours: 1)),
      inProductionAt: base.add(const Duration(hours: 3)),
      readyAt: base.add(const Duration(hours: 27)),
      completedAt: base.add(const Duration(hours: 33)),
      estimatedReadyAt: base.add(const Duration(hours: 30)),
    ),
    _buildOrder(
      id: 'order-2',
      clientId: 'client-1',
      productName: 'Dress / Ivory',
      amount: 70000,
      deliveryMethod: DeliveryMethod.courier,
      status: OrderStatus.completed,
      createdAt: base,
      acceptedAt: base.add(const Duration(minutes: 30)),
      inProductionAt: base.add(const Duration(hours: 1, minutes: 30)),
      readyAt: base.add(const Duration(hours: 27, minutes: 30)),
      completedAt: base.add(const Duration(hours: 33, minutes: 30)),
      estimatedReadyAt: base.add(const Duration(hours: 29)),
    ),
    _buildOrder(
      id: 'order-3',
      clientId: 'client-2',
      productName: 'Suit / Navy',
      amount: 120000,
      deliveryMethod: DeliveryMethod.pickup,
      status: OrderStatus.ready,
      createdAt: DateTime(2026, 3, 28, 9),
      acceptedAt: DateTime(2026, 3, 28, 10),
      inProductionAt: DateTime(2026, 3, 28, 11),
      readyAt: now.subtract(const Duration(hours: 3)),
      completedAt: null,
      estimatedReadyAt: now.subtract(const Duration(hours: 2)),
    ),
    _buildOrder(
      id: 'order-4',
      clientId: 'client-3',
      productName: 'Coat / Camel',
      amount: 50000,
      deliveryMethod: DeliveryMethod.courier,
      status: OrderStatus.inProduction,
      createdAt: base,
      acceptedAt: base.add(const Duration(minutes: 30)),
      inProductionAt: base.add(const Duration(hours: 1, minutes: 30)),
      readyAt: null,
      completedAt: null,
      estimatedReadyAt: base.add(const Duration(hours: 9)),
      lastStatusChangedAtOverride: base.add(
        const Duration(hours: 1, minutes: 30),
      ),
    ),
  ];
}

OrderModel _buildOrder({
  required String id,
  required String clientId,
  required String productName,
  required double amount,
  required DeliveryMethod deliveryMethod,
  required OrderStatus status,
  required DateTime createdAt,
  required DateTime acceptedAt,
  required DateTime inProductionAt,
  required DateTime? readyAt,
  required DateTime? completedAt,
  required DateTime estimatedReadyAt,
  DateTime? lastStatusChangedAtOverride,
}) {
  final historyEntries = <OrderHistoryEntry>[
    _historyEntry(
      id: '$id-new',
      orderId: id,
      fromStatus: null,
      toStatus: OrderStatus.newOrder,
      changedByRole: UserRole.client,
      createdAt: createdAt,
    ),
    _historyEntry(
      id: '$id-accepted',
      orderId: id,
      fromStatus: OrderStatus.newOrder,
      toStatus: OrderStatus.accepted,
      changedByRole: UserRole.franchisee,
      createdAt: acceptedAt,
    ),
    _historyEntry(
      id: '$id-production',
      orderId: id,
      fromStatus: OrderStatus.accepted,
      toStatus: OrderStatus.inProduction,
      changedByRole: UserRole.production,
      createdAt: inProductionAt,
    ),
    if (readyAt != null)
      _historyEntry(
        id: '$id-ready',
        orderId: id,
        fromStatus: OrderStatus.inProduction,
        toStatus: OrderStatus.ready,
        changedByRole: UserRole.production,
        createdAt: readyAt,
      ),
    if (completedAt != null)
      _historyEntry(
        id: '$id-completed',
        orderId: id,
        fromStatus: OrderStatus.ready,
        toStatus: OrderStatus.completed,
        changedByRole: UserRole.franchisee,
        createdAt: completedAt,
      ),
  ];

  return OrderModel(
    id: id,
    clientId: clientId,
    createdAt: createdAt,
    productName: productName,
    sizeLabel: 'M',
    amount: amount,
    totalAmount: amount,
    deliveryMethod: deliveryMethod,
    deliveryCity: 'Almaty',
    deliveryAddress: 'Dostyk 25',
    apartment: '12',
    paymentMethod: 'card',
    paymentLast4: '4242',
    status: status,
    acceptedAt: acceptedAt,
    completedAt: completedAt,
    estimatedReadyAt: estimatedReadyAt,
    lastStatusChangedAt:
        lastStatusChangedAtOverride ?? completedAt ?? readyAt ?? inProductionAt,
    historyEntries: historyEntries,
    timeline: const [],
  );
}

OrderHistoryEntry _historyEntry({
  required String id,
  required String orderId,
  required OrderStatus? fromStatus,
  required OrderStatus toStatus,
  required UserRole changedByRole,
  required DateTime createdAt,
}) {
  return OrderHistoryEntry(
    id: id,
    orderId: orderId,
    fromStatus: fromStatus,
    toStatus: toStatus,
    changedByUserId: 'user-$id',
    changedByRole: changedByRole,
    comment: '',
    createdAt: createdAt,
  );
}
