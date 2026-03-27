import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/order_status.dart';
import '../domain/models/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);

class OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) {
    return _firestore.collection('orders').doc(orderId).update({
      'status': newStatus.value,
    });
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
    bool isPreorder = false,
    DateTime? readyBy,
  }) {
    final doc = _firestore.collection('orders').doc();
    final order = OrderModel(
      id: doc.id,
      clientId: clientId,
      items: [productName, sizeLabel],
      createdAt: DateTime.now(),
      productName: productName,
      sizeLabel: sizeLabel,
      amount: amount,
      isPreorder: isPreorder,
      readyBy: readyBy,
    );

    return doc.set(order.toMap()).then((_) => doc.id);
  }

  List<OrderModel> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs.map(OrderModel.fromFirestore).toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}
