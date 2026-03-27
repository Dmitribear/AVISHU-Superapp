import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../features/auth/domain/user_role.dart';
import '../../../../shared/utils/firestore_parsing.dart';
import '../enums/order_status.dart';
import 'order_timeline_entry.dart';

class OrderHistoryEntry {
  final String id;
  final String orderId;
  final OrderStatus? fromStatus;
  final OrderStatus toStatus;
  final String changedByUserId;
  final UserRole changedByRole;
  final String comment;
  final DateTime createdAt;

  const OrderHistoryEntry({
    required this.id,
    required this.orderId,
    required this.fromStatus,
    required this.toStatus,
    required this.changedByUserId,
    required this.changedByRole,
    required this.comment,
    required this.createdAt,
  });

  factory OrderHistoryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String orderId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final fromValue = data['fromStatus'];

    return OrderHistoryEntry(
      id: stringFromFirestoreValue(data['id'], fallback: doc.id),
      orderId: stringFromFirestoreValue(data['orderId'], fallback: orderId),
      fromStatus: fromValue is String && fromValue.isNotEmpty
          ? OrderStatus.fromMap(fromValue)
          : null,
      toStatus: OrderStatus.fromMap(
        stringFromFirestoreValue(data['toStatus'], fallback: 'new'),
      ),
      changedByUserId: stringFromFirestoreValue(data['changedByUserId']),
      changedByRole: UserRole.fromMap(
        stringFromFirestoreValue(data['changedByRole'], fallback: 'client'),
      ),
      comment: stringFromFirestoreValue(data['comment']),
      createdAt:
          dateTimeFromFirestoreValue(data['createdAt']) ?? DateTime.now(),
    );
  }

  factory OrderHistoryEntry.fromLegacyTimeline({
    required String orderId,
    required int index,
    required OrderTimelineEntry timelineEntry,
  }) {
    return OrderHistoryEntry(
      id: 'legacy-$index',
      orderId: orderId,
      fromStatus: null,
      toStatus: timelineEntry.status,
      changedByUserId: '',
      changedByRole: UserRole.client,
      comment: timelineEntry.description,
      createdAt: timelineEntry.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'fromStatus': fromStatus?.value,
      'toStatus': toStatus.value,
      'changedByUserId': changedByUserId,
      'changedByRole': changedByRole.value,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  OrderTimelineEntry toTimelineEntry() {
    return OrderTimelineEntry(
      status: toStatus,
      createdAt: createdAt,
      title: toStatus.timelineTitle,
      description: comment.isNotEmpty ? comment : toStatus.roleDescription,
      actor: changedByRole.historyActorLabel,
    );
  }
}
