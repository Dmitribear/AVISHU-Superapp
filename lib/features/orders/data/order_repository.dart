import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/delivery_method.dart';
import '../domain/enums/order_status.dart';
import '../domain/models/order_model.dart';
import '../domain/models/order_timeline_entry.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);

class OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) {
    return _changeStatus(
      orderId: orderId,
      newStatus: newStatus,
      title: 'Статус обновлен',
      description: newStatus.roleDescription,
      actor: 'Система',
    );
  }

  Future<void> acceptOrder(String orderId, {String note = ''}) {
    return _changeStatus(
      orderId: orderId,
      newStatus: OrderStatus.accepted,
      title: 'Заказ подтвержден',
      description: note.isEmpty
          ? 'Франчайзи подтвердил заказ и передал его в очередь производства.'
          : note,
      actor: 'Франчайзи',
      franchiseeNote: note,
    );
  }

  Future<void> startProduction(String orderId, {String note = ''}) {
    return _changeStatus(
      orderId: orderId,
      newStatus: OrderStatus.inProduction,
      title: 'Пошив начат',
      description: note.isEmpty
          ? 'Заказ взят в работу мастером производства.'
          : note,
      actor: 'Производство',
      productionNote: note,
    );
  }

  Future<void> completeOrder(String orderId, {String note = ''}) {
    return _changeStatus(
      orderId: orderId,
      newStatus: OrderStatus.ready,
      title: 'Заказ готов',
      description: note.isEmpty
          ? 'Изделие завершено и готово к выдаче клиенту.'
          : note,
      actor: 'Производство',
      productionNote: note,
    );
  }

  Stream<List<OrderModel>> ordersByStatus(OrderStatus status) {
    return ordersByStatuses([status]);
  }

  Stream<List<OrderModel>> ordersByStatuses(List<OrderStatus> statuses) {
    if (statuses.isEmpty) {
      return Stream.value(const <OrderModel>[]);
    }

    final query = statuses.length == 1
        ? _firestore
              .collection('orders')
              .where('status', isEqualTo: statuses.first.value)
        : _firestore
              .collection('orders')
              .where(
                'status',
                whereIn: statuses.map((status) => status.value).toList(),
              );

    return query.snapshots().map(_mapAndSort);
  }

  Stream<List<OrderModel>> allOrders() {
    return _firestore.collection('orders').snapshots().map(_mapAndSort);
  }

  Stream<List<OrderModel>> clientOrders(String clientId) {
    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map(_mapAndSort);
  }

  Future<String> createOrder({
    required String clientId,
    required String productName,
    required String sizeLabel,
    required double amount,
    required DeliveryMethod deliveryMethod,
    required String deliveryCity,
    required String deliveryAddress,
    required String apartment,
    required String paymentLast4,
    bool isPreorder = false,
    DateTime? readyBy,
    String paymentMethod = 'card',
    String clientNote = '',
  }) async {
    final doc = _firestore.collection('orders').doc();
    final now = DateTime.now();
    final timeline = [
      OrderTimelineEntry(
        status: OrderStatus.newOrder,
        createdAt: now,
        title: 'Заказ оформлен',
        description: 'Клиент оформил заказ и выполнил оплату.',
        actor: 'Клиент',
      ),
    ];

    final order = OrderModel(
      id: doc.id,
      clientId: clientId,
      items: [productName, sizeLabel],
      createdAt: now,
      productName: productName,
      sizeLabel: sizeLabel,
      amount: amount,
      isPreorder: isPreorder,
      readyBy: readyBy,
      deliveryMethod: deliveryMethod,
      deliveryCity: deliveryCity,
      deliveryAddress: deliveryAddress,
      apartment: apartment,
      paymentMethod: paymentMethod,
      paymentLast4: paymentLast4,
      clientNote: clientNote,
      timeline: timeline,
    );

    await doc.set(order.toMap());
    return doc.id;
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final snapshot = await _firestore.collection('orders').doc(orderId).get();
    if (!snapshot.exists) {
      return null;
    }
    return OrderModel.fromFirestore(snapshot);
  }

  Future<void> _changeStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String title,
    required String description,
    required String actor,
    String? franchiseeNote,
    String? productionNote,
  }) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) {
      throw StateError('Order not found: $orderId');
    }

    final order = OrderModel.fromFirestore(doc);
    final timeline = [
      ...order.timeline,
      OrderTimelineEntry(
        status: newStatus,
        createdAt: DateTime.now(),
        title: title,
        description: description,
        actor: actor,
      ),
    ];

    await doc.reference.update({
      'status': newStatus.value,
      'timeline': timeline.map((entry) => entry.toMap()).toList(),
      if (franchiseeNote != null && franchiseeNote.isNotEmpty)
        'franchiseeNote': franchiseeNote,
      if (productionNote != null && productionNote.isNotEmpty)
        'productionNote': productionNote,
    });
  }

  List<OrderModel> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs.map(OrderModel.fromFirestore).toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}
