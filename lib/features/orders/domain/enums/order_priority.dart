enum OrderPriority {
  high('high'),
  normal('normal');

  final String value;
  const OrderPriority(this.value);

  factory OrderPriority.fromMap(String? value) {
    final normalized = value?.trim().toLowerCase() ?? 'normal';
    return OrderPriority.values.firstWhere(
      (priority) => priority.value == normalized,
      orElse: () => OrderPriority.normal,
    );
  }
}
