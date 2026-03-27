import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/delivery_method.dart';
import '../enums/order_status.dart';
import 'order_timeline_entry.dart';

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
  final DeliveryMethod deliveryMethod;
  final String deliveryCity;
  final String deliveryAddress;
  final String apartment;
  final String paymentMethod;
  final String paymentLast4;
  final String clientNote;
  final String franchiseeNote;
  final String productionNote;
  final List<OrderTimelineEntry> timeline;

  const OrderModel({
    required this.id,
    required this.clientId,
    required this.items,
    required this.createdAt,
    required this.productName,
    required this.sizeLabel,
    required this.amount,
    required this.deliveryMethod,
    required this.deliveryCity,
    required this.deliveryAddress,
    required this.apartment,
    required this.paymentMethod,
    required this.paymentLast4,
    required this.timeline,
    this.status = OrderStatus.newOrder,
    this.isPreorder = false,
    this.readyBy,
    this.clientNote = '',
    this.franchiseeNote = '',
    this.productionNote = '',
  });

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final items = List<String>.from(data['items'] ?? const <String>[]);
    final createdAt = data['createdAt'];
    final readyBy = data['readyBy'];
    final timelineRaw = List<Map<String, dynamic>>.from(
      data['timeline'] ?? const <Map<String, dynamic>>[],
    );

    return OrderModel(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      status: OrderStatus.fromMap(data['status'] as String? ?? 'New'),
      items: items,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      productName: data['productName'] as String? ?? (items.isNotEmpty ? items.first : 'Изделие'),
      sizeLabel: data['sizeLabel'] as String? ?? (items.length > 1 ? items[1] : 'ONE SIZE'),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      isPreorder: data['isPreorder'] == true,
      readyBy: readyBy is Timestamp ? readyBy.toDate() : null,
      deliveryMethod: DeliveryMethod.fromMap(data['deliveryMethod'] as String?),
      deliveryCity: data['deliveryCity'] as String? ?? '',
      deliveryAddress: data['deliveryAddress'] as String? ?? '',
      apartment: data['apartment'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? 'card',
      paymentLast4: data['paymentLast4'] as String? ?? '',
      clientNote: data['clientNote'] as String? ?? '',
      franchiseeNote: data['franchiseeNote'] as String? ?? '',
      productionNote: data['productionNote'] as String? ?? '',
      timeline: timelineRaw.map(OrderTimelineEntry.fromMap).toList(),
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
      'deliveryMethod': deliveryMethod.value,
      'deliveryCity': deliveryCity,
      'deliveryAddress': deliveryAddress,
      'apartment': apartment,
      'paymentMethod': paymentMethod,
      'paymentLast4': paymentLast4,
      'clientNote': clientNote,
      'franchiseeNote': franchiseeNote,
      'productionNote': productionNote,
      'timeline': timeline.map((entry) => entry.toMap()).toList(),
    };
  }

  String get shortId => id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

  String get formattedAddress {
    if (deliveryAddress.trim().isEmpty) {
      return deliveryCity;
    }
    if (apartment.trim().isEmpty) {
      return '$deliveryCity, $deliveryAddress';
    }
    return '$deliveryCity, $deliveryAddress, кв. $apartment';
  }

  OrderModel copyWith({
    OrderStatus? status,
    DateTime? readyBy,
    String? franchiseeNote,
    String? productionNote,
    List<OrderTimelineEntry>? timeline,
  }) {
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
      readyBy: readyBy ?? this.readyBy,
      deliveryMethod: deliveryMethod,
      deliveryCity: deliveryCity,
      deliveryAddress: deliveryAddress,
      apartment: apartment,
      paymentMethod: paymentMethod,
      paymentLast4: paymentLast4,
      clientNote: clientNote,
      franchiseeNote: franchiseeNote ?? this.franchiseeNote,
      productionNote: productionNote ?? this.productionNote,
      timeline: timeline ?? this.timeline,
    );
  }
}
