import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/firestore_parsing.dart';

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final String sizeLabel;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final bool isPreorder;
  final DateTime? readyBy;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.sizeLabel,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.isPreorder,
    required this.readyBy,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String orderId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt =
        dateTimeFromFirestoreValue(data['createdAt']) ?? DateTime.now();
    final updatedAt =
        dateTimeFromFirestoreValue(data['updatedAt']) ?? createdAt;
    final unitPrice = doubleFromFirestoreValue(data['unitPrice']);
    final quantity = intFromFirestoreValue(data['quantity'], fallback: 1);

    return OrderItemModel(
      id: stringFromFirestoreValue(data['id'], fallback: doc.id),
      orderId: stringFromFirestoreValue(data['orderId'], fallback: orderId),
      productId: stringFromFirestoreValue(data['productId']),
      productName: stringFromFirestoreValue(data['productName']),
      sizeLabel: stringFromFirestoreValue(data['sizeLabel']),
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: doubleFromFirestoreValue(
        data['lineTotal'],
        fallback: unitPrice * quantity,
      ),
      isPreorder: boolFromFirestoreValue(data['isPreorder']),
      readyBy: dateTimeFromFirestoreValue(data['readyBy']),
      imageUrl: stringFromFirestoreValue(data['imageUrl']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'sizeLabel': sizeLabel,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'isPreorder': isPreorder,
      'readyBy': timestampFromDate(readyBy),
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
