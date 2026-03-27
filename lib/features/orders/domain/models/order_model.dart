import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/order_status.dart';

class OrderModel {
  final String id;
  final String clientId;
  final OrderStatus status;
  final List<String> items;
  final DateTime createdAt;
  final String productName;
  final String sizeLabel;
  final double amount;
  final bool isPreorder;
  final DateTime? readyBy;

  OrderModel({
    required this.id,
    required this.clientId,
    this.status = OrderStatus.newOrder,
    required this.items,
    required this.createdAt,
    required this.productName,
    required this.sizeLabel,
    required this.amount,
    this.isPreorder = false,
    this.readyBy,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final items = List<String>.from(data['items'] ?? const <String>[]);
    final createdAt = data['createdAt'];
    final readyBy = data['readyBy'];
    final productName =
        data['productName'] as String? ??
        (items.isNotEmpty ? items.first : 'AVISHU ITEM');
    final sizeLabel =
        data['sizeLabel'] as String? ??
        (items.length > 1 ? items[1] : 'ONE SIZE');

    return OrderModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      status: OrderStatus.fromMap(data['status'] ?? 'New'),
      items: items,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      productName: productName,
      sizeLabel: sizeLabel,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      isPreorder: data['isPreorder'] == true,
      readyBy: readyBy is Timestamp ? readyBy.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'status': status.value,
      'items': items,
      'createdAt': Timestamp.fromDate(createdAt),
      'productName': productName,
      'sizeLabel': sizeLabel,
      'amount': amount,
      'isPreorder': isPreorder,
      'readyBy': readyBy == null ? null : Timestamp.fromDate(readyBy!),
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
      productName: productName,
      sizeLabel: sizeLabel,
      amount: amount,
      isPreorder: isPreorder,
      readyBy: readyBy,
    );
  }
}
