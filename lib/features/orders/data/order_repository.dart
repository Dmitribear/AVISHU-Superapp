import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_role.dart';
import '../../products/domain/models/product_model.dart';
import '../domain/enums/delivery_method.dart';
import '../domain/enums/fulfillment_type.dart';
import '../domain/enums/order_priority.dart';
import '../domain/enums/order_status.dart';
import '../domain/enums/payment_status.dart';
import '../domain/models/order_history_entry.dart';
import '../domain/models/order_item_model.dart';
import '../domain/models/order_model.dart';
import '../domain/services/order_status_transition_service.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) =>
      OrderRepository(statusTransitionService: OrderStatusTransitionService()),
);

class OrderRepository {
  final FirebaseFirestore _firestore;
  final OrderStatusTransitionService _statusTransitionService;

  OrderRepository({
    FirebaseFirestore? firestore,
    OrderStatusTransitionService? statusTransitionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _statusTransitionService =
           statusTransitionService ?? OrderStatusTransitionService();

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> _orderItems(String orderId) {
    return _orders.doc(orderId).collection('items');
  }

  CollectionReference<Map<String, dynamic>> _orderHistory(String orderId) {
    return _orders.doc(orderId).collection('history');
  }

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String note = '',
    String changedByUserId = '',
    UserRole changedByRole = UserRole.admin,
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: newStatus,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: changedByRole,
    );
  }

  Future<void> acceptOrder(
    String orderId, {
    String note = '',
    String changedByUserId = '',
    String franchiseeId = '',
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: OrderStatus.accepted,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: UserRole.franchisee,
      franchiseeId: franchiseeId,
    );
  }

  Future<void> startProduction(
    String orderId, {
    String note = '',
    String changedByUserId = '',
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: OrderStatus.inProduction,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: UserRole.production,
    );
  }

  Future<void> completeOrder(
    String orderId, {
    String note = '',
    String changedByUserId = '',
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: OrderStatus.ready,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: UserRole.production,
    );
  }

  Future<void> finalizeOrder(
    String orderId, {
    String note = '',
    String changedByUserId = '',
    UserRole changedByRole = UserRole.franchisee,
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: OrderStatus.completed,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: changedByRole,
    );
  }

  Future<void> cancelOrder(
    String orderId, {
    String note = '',
    String changedByUserId = '',
    UserRole changedByRole = UserRole.franchisee,
  }) {
    return _transitionOrder(
      orderId: orderId,
      newStatus: OrderStatus.cancelled,
      note: note,
      changedByUserId: changedByUserId,
      changedByRole: changedByRole,
    );
  }

  Stream<List<OrderModel>> ordersByStatus(OrderStatus status) {
    return ordersByStatuses(<OrderStatus>[status]);
  }

  Stream<List<OrderModel>> ordersByStatuses(List<OrderStatus> statuses) {
    if (statuses.isEmpty) {
      return Stream.value(const <OrderModel>[]);
    }

    final values = statuses.map((status) => status.value).toList();
    final query = values.length == 1
        ? _orders.where('status', isEqualTo: values.first)
        : _orders.where('status', whereIn: values);

    return query.snapshots().asyncMap(_hydrateAndSort);
  }

  Stream<List<OrderModel>> allOrders() {
    return _orders.snapshots().asyncMap(_hydrateAndSort);
  }

  Stream<List<OrderModel>> clientOrders(String clientId) {
    return _orders
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .asyncMap(_hydrateAndSort);
  }

  Stream<List<OrderModel>> franchiseeOrders({String? franchiseeId}) {
    final query = franchiseeId == null || franchiseeId.isEmpty
        ? _orders
        : _orders.where('franchiseeId', isEqualTo: franchiseeId);
    return query.snapshots().asyncMap(_hydrateAndSort);
  }

  Stream<List<OrderModel>> productionQueue() {
    return ordersByStatuses(const <OrderStatus>[
      OrderStatus.accepted,
      OrderStatus.inProduction,
      OrderStatus.ready,
    ]);
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
    String productId = '',
    String imageUrl = '',
    int quantity = 1,
    double? unitPrice,
    String currency = 'KZT',
  }) async {
    final doc = _orders.doc();
    final itemDoc = _orderItems(doc.id).doc();
    final historyDoc = _orderHistory(doc.id).doc();
    final now = DateTime.now();
    final safeQuantity = quantity < 1 ? 1 : quantity;
    final product = await _loadProduct(productId);
    final resolvedIsPreorder =
        isPreorder || (product?.isPreorderAvailable ?? false);
    final resolvedUnitPrice =
        unitPrice ?? product?.price ?? (amount / safeQuantity);
    final estimatedReadyAt = _resolveEstimatedReadyAt(
      createdAt: now,
      requestedReadyAt: readyBy,
      isPreorder: resolvedIsPreorder,
      product: product,
    );
    final priority = _resolvePriority(
      isPreorder: resolvedIsPreorder,
      comment: clientNote,
    );
    final orderNumber = _buildOrderNumber(now, doc.id);
    final item = OrderItemModel(
      id: itemDoc.id,
      orderId: doc.id,
      productId: productId,
      productName: productName,
      sizeLabel: sizeLabel,
      quantity: safeQuantity,
      unitPrice: resolvedUnitPrice,
      lineTotal: resolvedUnitPrice * safeQuantity,
      isPreorder: resolvedIsPreorder,
      readyBy: estimatedReadyAt,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : (product?.coverImage ?? ''),
      createdAt: now,
      updatedAt: now,
    );
    final historyEntry = OrderHistoryEntry(
      id: historyDoc.id,
      orderId: doc.id,
      fromStatus: null,
      toStatus: OrderStatus.newOrder,
      changedByUserId: clientId,
      changedByRole: UserRole.client,
      comment: clientNote,
      createdAt: now,
    );
    final order = OrderModel(
      id: doc.id,
      orderNumber: orderNumber,
      clientId: clientId,
      franchiseeId: '',
      status: OrderStatus.newOrder,
      paymentStatus: PaymentStatus.paid,
      fulfillmentType: resolvedIsPreorder
          ? FulfillmentType.preorder
          : FulfillmentType.inStock,
      totalAmount: amount,
      currency: currency,
      comment: clientNote,
      priority: priority,
      estimatedReadyAt: estimatedReadyAt,
      acceptedAt: null,
      completedAt: null,
      lastStatusChangedAt: now,
      createdAt: now,
      updatedAt: now,
      orderItemsList: <OrderItemModel>[item],
      historyEntries: <OrderHistoryEntry>[historyEntry],
      items: <String>[productName, sizeLabel],
      productName: productName,
      sizeLabel: sizeLabel,
      amount: amount,
      isPreorder: resolvedIsPreorder,
      readyBy: estimatedReadyAt,
      deliveryMethod: deliveryMethod,
      deliveryCity: deliveryCity,
      deliveryAddress: deliveryAddress,
      apartment: apartment,
      paymentMethod: paymentMethod,
      paymentLast4: paymentLast4,
      clientNote: clientNote,
      timeline: const [],
    );

    final batch = _firestore.batch();
    batch.set(doc, order.toMap());
    batch.set(itemDoc, item.toMap());
    batch.set(historyDoc, historyEntry.toMap());
    await batch.commit();
    return doc.id;
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final snapshot = await _orders.doc(orderId).get();
    if (!snapshot.exists) {
      return null;
    }
    return _hydrateOrder(snapshot);
  }

  Future<void> _transitionOrder({
    required String orderId,
    required OrderStatus newStatus,
    required String note,
    required String changedByUserId,
    required UserRole changedByRole,
    String franchiseeId = '',
  }) async {
    final order = await getOrderById(orderId);
    if (order == null) {
      throw StateError('Order not found: $orderId');
    }

    _statusTransitionService.validateTransition(order.status, newStatus);

    final now = DateTime.now();
    final historyDoc = _orderHistory(orderId).doc();
    final historyEntry = OrderHistoryEntry(
      id: historyDoc.id,
      orderId: orderId,
      fromStatus: order.status,
      toStatus: newStatus,
      changedByUserId: changedByUserId,
      changedByRole: changedByRole,
      comment: note,
      createdAt: now,
    );

    final updates = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': Timestamp.fromDate(now),
      'lastStatusChangedAt': Timestamp.fromDate(now),
      if (newStatus == OrderStatus.accepted)
        'acceptedAt': Timestamp.fromDate(now),
      if (newStatus == OrderStatus.completed)
        'completedAt': Timestamp.fromDate(now),
      if (franchiseeId.isNotEmpty) 'franchiseeId': franchiseeId,
      if (changedByRole == UserRole.franchisee && note.isNotEmpty)
        'franchiseeNote': note,
      if (changedByRole == UserRole.production && note.isNotEmpty)
        'productionNote': note,
    };

    final batch = _firestore.batch();
    batch.update(_orders.doc(orderId), updates);
    batch.set(historyDoc, historyEntry.toMap());
    await batch.commit();
  }

  Future<List<OrderModel>> _hydrateAndSort(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final orders = await Future.wait(snapshot.docs.map(_hydrateOrder));
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<OrderModel> _hydrateOrder(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final itemsSnapshot = await _orderItems(doc.id).get();
    final historySnapshot = await _orderHistory(
      doc.id,
    ).orderBy('createdAt').get().catchError((_) => _orderHistory(doc.id).get());
    final items = itemsSnapshot.docs
        .map((itemDoc) => OrderItemModel.fromFirestore(itemDoc, doc.id))
        .toList();
    final history =
        historySnapshot.docs
            .map(
              (historyDoc) =>
                  OrderHistoryEntry.fromFirestore(historyDoc, doc.id),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return OrderModel.fromFirestore(doc, orderItems: items, history: history);
  }

  Future<ProductModel?> _loadProduct(String productId) async {
    if (productId.isEmpty) {
      return null;
    }
    final snapshot = await _products.doc(productId).get();
    if (!snapshot.exists) {
      return null;
    }
    return ProductModel.fromFirestore(snapshot);
  }

  DateTime? _resolveEstimatedReadyAt({
    required DateTime createdAt,
    required DateTime? requestedReadyAt,
    required bool isPreorder,
    required ProductModel? product,
  }) {
    if (requestedReadyAt != null) {
      return requestedReadyAt;
    }

    final defaultDays = product?.defaultProductionDays ?? 0;
    if (isPreorder || defaultDays > 0) {
      final days = defaultDays > 0 ? defaultDays : 3;
      return createdAt.add(Duration(days: days));
    }

    return null;
  }

  OrderPriority _resolvePriority({
    required bool isPreorder,
    required String comment,
  }) {
    final normalizedComment = comment.toLowerCase();
    final hasUrgentFlag =
        normalizedComment.contains('urgent') ||
        normalizedComment.contains('asap') ||
        normalizedComment.contains('сроч');

    if (isPreorder || hasUrgentFlag) {
      return OrderPriority.high;
    }
    return OrderPriority.normal;
  }

  String _buildOrderNumber(DateTime now, String orderId) {
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final suffix = orderId.substring(0, 5).toUpperCase();
    return 'AV-$month$day-$suffix';
  }
}
