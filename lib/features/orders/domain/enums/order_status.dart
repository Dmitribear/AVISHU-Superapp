enum OrderStatus {
  newOrder('New'),
  accepted('Accepted'),
  inProduction('InProduction'),
  ready('Ready');

  final String value;
  const OrderStatus(this.value);

  factory OrderStatus.fromMap(String value) {
    return OrderStatus.values.firstWhere((e) => e.value == value, orElse: () => OrderStatus.newOrder);
  }
}
