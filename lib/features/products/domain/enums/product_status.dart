enum ProductStatus {
  active('active'),
  draft('draft'),
  archived('archived');

  final String value;
  const ProductStatus(this.value);

  factory ProductStatus.fromMap(String? value) {
    final normalized = value?.trim().toLowerCase() ?? 'active';
    return ProductStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => ProductStatus.active,
    );
  }
}
