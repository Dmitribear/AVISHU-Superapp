import '../enums/order_status.dart';

class OrderTimelineEntry {
  final OrderStatus status;
  final DateTime createdAt;
  final String title;
  final String description;
  final String actor;

  const OrderTimelineEntry({
    required this.status,
    required this.createdAt,
    required this.title,
    required this.description,
    required this.actor,
  });

  factory OrderTimelineEntry.fromMap(Map<String, dynamic> map) {
    return OrderTimelineEntry(
      status: OrderStatus.fromMap(map['status'] as String? ?? 'New'),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      actor: map['actor'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'title': title,
      'description': description,
      'actor': actor,
    };
  }
}
