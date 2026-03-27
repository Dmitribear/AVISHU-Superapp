enum FulfillmentType {
  inStock('in_stock'),
  preorder('preorder');

  final String value;
  const FulfillmentType(this.value);

  factory FulfillmentType.fromMap(String? value) {
    final normalized = value?.trim().toLowerCase() ?? 'in_stock';
    return FulfillmentType.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => FulfillmentType.inStock,
    );
  }
}
