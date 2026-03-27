import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/order_status.dart';

class OrderModel {
  final String id;
  final String clientId;
  final OrderStatus status; 
  final List<String> items;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      status: OrderStatus.fromMap(data['status'] ?? 'New'),
      items: List<String>.from(data['items'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'status': status.value,
      'items': items,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  OrderModel shiftToNextState() {
    switch (status) {
      case OrderStatus.newOrder:
        return copyWith(status: OrderStatus.accepted);
      case OrderStatus.accepted:
        return copyWith(status: OrderStatus.inProduction);
      case OrderStatus.inProduction:
        return copyWith(status: OrderStatus.ready);
      case OrderStatus.ready:
        throw Exception('Order is already in final state: Ready');
    }
  }

  OrderModel copyWith({OrderStatus? status}) {
    return OrderModel(
      id: id,
      clientId: clientId,
      status: status ?? this.status,
      items: items,
      createdAt: createdAt,
    );
  }
}
