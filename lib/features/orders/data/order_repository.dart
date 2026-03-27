import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/order_model.dart';
import '../domain/enums/order_status.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());

class OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    _firestore.collection('orders').doc(orderId).update({
      'status': newStatus.value,
    });
  }

  Stream<List<OrderModel>> ordersByStatus(OrderStatus status) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status.value)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  Stream<List<OrderModel>> clientOrders(String clientId) {
    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }
}
