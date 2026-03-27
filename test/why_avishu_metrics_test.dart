import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/features/orders/domain/models/order_model.dart';
import 'package:avishu/features/franchise_value/presentation/why_avishu_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deriveWhyAvishuMetrics aggregates live franchise metrics', () {
    final now = DateTime(2026, 3, 28, 15, 0);
    final today = DateTime(2026, 3, 28, 9, 0);
    final yesterday = DateTime(2026, 3, 27, 12, 0);

    final orders = <OrderModel>[
      OrderModel(
        id: '1',
        clientId: 'client-1',
        createdAt: today,
        productName: 'Skirt SHE',
        sizeLabel: 'M',
        amount: 30500,
        deliveryMethod: DeliveryMethod.courier,
        deliveryCity: 'Almaty',
        deliveryAddress: 'Dostyk 25',
        apartment: '12',
        paymentMethod: 'card',
        paymentLast4: '4242',
        status: OrderStatus.newOrder,
        lastStatusChangedAt: today,
        timeline: const [],
      ),
      OrderModel(
        id: '2',
        clientId: 'client-2',
        createdAt: today,
        productName: 'Suit LINE',
        sizeLabel: 'L',
        amount: 68200,
        deliveryMethod: DeliveryMethod.pickup,
        deliveryCity: 'Almaty',
        deliveryAddress: 'Esentai',
        apartment: '',
        paymentMethod: 'card',
        paymentLast4: '1111',
        status: OrderStatus.inProduction,
        lastStatusChangedAt: today.add(const Duration(hours: 2)),
        timeline: const [],
      ),
      OrderModel(
        id: '3',
        clientId: 'client-3',
        createdAt: yesterday,
        productName: 'Cardigan LUNE',
        sizeLabel: 'S',
        amount: 26800,
        deliveryMethod: DeliveryMethod.courier,
        deliveryCity: 'Almaty',
        deliveryAddress: 'Mega',
        apartment: '',
        paymentMethod: 'card',
        paymentLast4: '0000',
        status: OrderStatus.ready,
        lastStatusChangedAt: yesterday.add(const Duration(hours: 5)),
        timeline: const [],
      ),
    ];

    final metrics = deriveWhyAvishuMetrics(orders, now: now);

    expect(metrics.todayOrders, 2);
    expect(metrics.activeOrders, 3);
    expect(metrics.inProductionOrders, 1);
    expect(metrics.readyOrders, 1);
    expect(metrics.averageTimeToReady, '5 H');
  });
}
