import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/features/orders/domain/models/order_model.dart';
import 'package:avishu/features/orders/domain/models/order_timeline_entry.dart';

void main() {
  test('order model keeps address and timeline data', () {
    final order = OrderModel(
      id: 'abc123',
      clientId: 'client-1',
      status: OrderStatus.accepted,
      items: const ['Structured Overcoat', '42'],
      createdAt: DateTime(2026, 3, 27, 10, 30),
      productName: 'Structured Overcoat',
      sizeLabel: '42',
      amount: 865,
      isPreorder: true,
      readyBy: DateTime(2026, 4, 10),
      deliveryMethod: DeliveryMethod.courier,
      deliveryCity: 'Алматы',
      deliveryAddress: 'пр. Достык, 25',
      apartment: '12',
      paymentMethod: 'card',
      paymentLast4: '4242',
      clientNote: 'Позвонить за час',
      timeline: [
        OrderTimelineEntry(
          status: OrderStatus.newOrder,
          createdAt: DateTime(2026, 3, 27, 10, 30),
          title: 'Заказ оформлен',
          description: 'Клиент оформил заказ.',
          actor: 'Клиент',
        ),
      ],
    );

    expect(order.shortId, 'ABC123');
    expect(order.formattedAddress, 'Алматы, пр. Достык, 25, кв. 12');
    expect(order.timeline.single.actor, 'Клиент');
    expect(order.deliveryMethod.fee, 25);
  });
}
