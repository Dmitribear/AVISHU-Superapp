import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/firestore_parsing.dart';
import '../enums/delivery_method.dart';
import '../enums/fulfillment_type.dart';
import '../enums/order_priority.dart';
import '../enums/order_status.dart';
import '../enums/payment_status.dart';
import 'order_history_entry.dart';
import 'order_item_model.dart';
import 'order_timeline_entry.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String clientId;
  final String franchiseeId;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final FulfillmentType fulfillmentType;
  final double totalAmount;
  final String currency;
  final String comment;
  final OrderPriority priority;
  final DateTime? estimatedReadyAt;
  final DateTime? acceptedAt;
  final DateTime? sentToFactoryAt;
  final DateTime? completedAt;
  final DateTime lastStatusChangedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItemModel> orderItems;
  final List<OrderHistoryEntry> history;

  // Legacy UI compatibility fields.
  final List<String> items;
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

  OrderModel({
    required this.id,
    required this.clientId,
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
    required List<OrderTimelineEntry> timeline,
    this.status = OrderStatus.newOrder,
    this.items = const <String>[],
    this.isPreorder = false,
    this.readyBy,
    this.clientNote = '',
    this.franchiseeNote = '',
    this.productionNote = '',
    this.orderNumber = '',
    this.franchiseeId = '',
    this.paymentStatus = PaymentStatus.pending,
    FulfillmentType? fulfillmentType,
    double? totalAmount,
    this.currency = 'KZT',
    String? comment,
    this.priority = OrderPriority.normal,
    DateTime? estimatedReadyAt,
    this.acceptedAt,
    this.sentToFactoryAt,
    this.completedAt,
    DateTime? lastStatusChangedAt,
    DateTime? updatedAt,
    List<OrderItemModel> orderItemsList = const <OrderItemModel>[],
    List<OrderHistoryEntry> historyEntries = const <OrderHistoryEntry>[],
  }) : fulfillmentType =
           fulfillmentType ??
           (isPreorder ? FulfillmentType.preorder : FulfillmentType.inStock),
       totalAmount = totalAmount ?? amount,
       comment = comment ?? clientNote,
       estimatedReadyAt = estimatedReadyAt ?? readyBy,
       lastStatusChangedAt = lastStatusChangedAt ?? createdAt,
       updatedAt = updatedAt ?? createdAt,
       orderItems = orderItemsList,
       history = historyEntries,
       timeline = timeline.isNotEmpty
           ? timeline
           : historyEntries.map((entry) => entry.toTimelineEntry()).toList();

  factory OrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<OrderItemModel> orderItems = const <OrderItemModel>[],
    List<OrderHistoryEntry> history = const <OrderHistoryEntry>[],
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt =
        dateTimeFromFirestoreValue(data['createdAt']) ?? DateTime.now();
    final updatedAt =
        dateTimeFromFirestoreValue(data['updatedAt']) ?? createdAt;

    final fallbackTimeline =
        (data['timeline'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(OrderTimelineEntry.fromMap)
            .toList();
    final resolvedHistory = history.isNotEmpty
        ? history
        : fallbackTimeline.indexed
              .map(
                (entry) => OrderHistoryEntry.fromLegacyTimeline(
                  orderId: doc.id,
                  index: entry.$1,
                  timelineEntry: entry.$2,
                ),
              )
              .toList();
    final resolvedTimeline = resolvedHistory.isNotEmpty
        ? resolvedHistory.map((entry) => entry.toTimelineEntry()).toList()
        : fallbackTimeline;

    final resolvedItems = orderItems.isNotEmpty
        ? orderItems
        : _legacyItemsFromData(doc.id, data, createdAt, updatedAt);
    final legacyItems = stringListFromFirestoreValue(data['items']);
    final primaryItem = resolvedItems.isNotEmpty ? resolvedItems.first : null;
    final totalAmount = doubleFromFirestoreValue(
      data['totalAmount'],
      fallback: doubleFromFirestoreValue(data['amount']),
    );
    final comment = stringFromFirestoreValue(
      data['comment'],
      fallback: stringFromFirestoreValue(data['clientNote']),
    );
    final fulfillmentType = data['fulfillmentType'] is String
        ? FulfillmentType.fromMap(data['fulfillmentType'] as String?)
        : ((boolFromFirestoreValue(data['isPreorder']) ||
                  resolvedItems.any((item) => item.isPreorder))
              ? FulfillmentType.preorder
              : FulfillmentType.inStock);
    final status = OrderStatus.fromMap(
      stringFromFirestoreValue(data['status'], fallback: 'new'),
    );

    return OrderModel(
      id: doc.id,
      orderNumber: stringFromFirestoreValue(
        data['orderNumber'],
        fallback:
            'AV-${createdAt.year}-${doc.id.substring(0, 5).toUpperCase()}',
      ),
      clientId: stringFromFirestoreValue(data['clientId']),
      franchiseeId: stringFromFirestoreValue(data['franchiseeId']),
      status: status,
      paymentStatus: PaymentStatus.fromMap(data['paymentStatus'] as String?),
      fulfillmentType: fulfillmentType,
      totalAmount: totalAmount,
      currency: stringFromFirestoreValue(data['currency'], fallback: 'KZT'),
      comment: comment,
      priority: data['priority'] is String
          ? OrderPriority.fromMap(data['priority'] as String?)
          : (fulfillmentType == FulfillmentType.preorder
                ? OrderPriority.high
                : OrderPriority.normal),
      estimatedReadyAt:
          dateTimeFromFirestoreValue(data['estimatedReadyAt']) ??
          dateTimeFromFirestoreValue(data['readyBy']),
      acceptedAt: dateTimeFromFirestoreValue(data['acceptedAt']),
      sentToFactoryAt: dateTimeFromFirestoreValue(data['sentToFactoryAt']),
      completedAt: dateTimeFromFirestoreValue(data['completedAt']),
      lastStatusChangedAt:
          dateTimeFromFirestoreValue(data['lastStatusChangedAt']) ?? createdAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      orderItemsList: resolvedItems,
      historyEntries: resolvedHistory,
      items: legacyItems.isNotEmpty
          ? legacyItems
          : primaryItem == null
          ? const <String>[]
          : <String>[primaryItem.productName, primaryItem.sizeLabel],
      productName: stringFromFirestoreValue(
        data['productName'],
        fallback: primaryItem?.productName ?? 'Item',
      ),
      sizeLabel: stringFromFirestoreValue(
        data['sizeLabel'],
        fallback: primaryItem?.sizeLabel ?? 'ONE SIZE',
      ),
      amount: doubleFromFirestoreValue(data['amount'], fallback: totalAmount),
      isPreorder:
          boolFromFirestoreValue(data['isPreorder']) ||
          resolvedItems.any((item) => item.isPreorder),
      readyBy:
          dateTimeFromFirestoreValue(data['readyBy']) ??
          dateTimeFromFirestoreValue(data['estimatedReadyAt']),
      deliveryMethod: DeliveryMethod.fromMap(data['deliveryMethod'] as String?),
      deliveryCity: stringFromFirestoreValue(data['deliveryCity']),
      deliveryAddress: stringFromFirestoreValue(data['deliveryAddress']),
      apartment: stringFromFirestoreValue(data['apartment']),
      paymentMethod: stringFromFirestoreValue(
        data['paymentMethod'],
        fallback: 'card',
      ),
      paymentLast4: stringFromFirestoreValue(data['paymentLast4']),
      clientNote: stringFromFirestoreValue(
        data['clientNote'],
        fallback: comment,
      ),
      franchiseeNote: stringFromFirestoreValue(data['franchiseeNote']),
      productionNote: stringFromFirestoreValue(data['productionNote']),
      timeline: resolvedTimeline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'clientId': clientId,
      'franchiseeId': franchiseeId,
      'status': status.value,
      'paymentStatus': paymentStatus.value,
      'fulfillmentType': fulfillmentType.value,
      'totalAmount': totalAmount,
      'currency': currency,
      'comment': comment,
      'priority': priority.value,
      'estimatedReadyAt': timestampFromDate(estimatedReadyAt),
      'acceptedAt': timestampFromDate(acceptedAt),
      'sentToFactoryAt': timestampFromDate(sentToFactoryAt),
      'completedAt': timestampFromDate(completedAt),
      'lastStatusChangedAt': Timestamp.fromDate(lastStatusChangedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Legacy compatibility for the current UI.
      'items': items,
      'productName': productName,
      'sizeLabel': sizeLabel,
      'amount': amount,
      'isPreorder': isPreorder,
      'readyBy': timestampFromDate(readyBy),
      'deliveryMethod': deliveryMethod.value,
      'deliveryCity': deliveryCity,
      'deliveryAddress': deliveryAddress,
      'apartment': apartment,
      'paymentMethod': paymentMethod,
      'paymentLast4': paymentLast4,
      'clientNote': clientNote,
      'franchiseeNote': franchiseeNote,
      'productionNote': productionNote,
    };
  }

  String get shortId =>
      id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

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
    List<OrderHistoryEntry>? history,
    List<OrderItemModel>? orderItems,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? sentToFactoryAt,
    DateTime? completedAt,
    DateTime? lastStatusChangedAt,
    OrderPriority? priority,
    DateTime? estimatedReadyAt,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      clientId: clientId,
      franchiseeId: franchiseeId,
      status: status ?? this.status,
      paymentStatus: paymentStatus,
      fulfillmentType: fulfillmentType,
      totalAmount: totalAmount,
      currency: currency,
      comment: comment,
      priority: priority ?? this.priority,
      estimatedReadyAt: estimatedReadyAt ?? this.estimatedReadyAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      sentToFactoryAt: sentToFactoryAt ?? this.sentToFactoryAt,
      completedAt: completedAt ?? this.completedAt,
      lastStatusChangedAt: lastStatusChangedAt ?? this.lastStatusChangedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderItemsList: orderItems ?? this.orderItems,
      historyEntries: history ?? this.history,
      items: items,
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

  static List<OrderItemModel> _legacyItemsFromData(
    String orderId,
    Map<String, dynamic> data,
    DateTime createdAt,
    DateTime updatedAt,
  ) {
    final productName = stringFromFirestoreValue(data['productName']);
    if (productName.isEmpty) {
      return const <OrderItemModel>[];
    }

    return <OrderItemModel>[
      OrderItemModel(
        id: 'legacy-item',
        orderId: orderId,
        productId: stringFromFirestoreValue(data['productId']),
        productName: productName,
        sizeLabel: stringFromFirestoreValue(
          data['sizeLabel'],
          fallback: 'ONE SIZE',
        ),
        quantity: intFromFirestoreValue(data['quantity'], fallback: 1),
        unitPrice: doubleFromFirestoreValue(
          data['amount'],
          fallback: doubleFromFirestoreValue(data['totalAmount']),
        ),
        lineTotal: doubleFromFirestoreValue(
          data['amount'],
          fallback: doubleFromFirestoreValue(data['totalAmount']),
        ),
        isPreorder: boolFromFirestoreValue(data['isPreorder']),
        readyBy: dateTimeFromFirestoreValue(data['readyBy']),
        imageUrl: stringFromFirestoreValue(data['imageUrl']),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ];
  }
}
