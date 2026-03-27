enum PaymentStatus {
  pending('pending'),
  paid('paid'),
  failed('failed');

  final String value;
  const PaymentStatus(this.value);

  factory PaymentStatus.fromMap(String? value) {
    final normalized = value?.trim().toLowerCase() ?? 'pending';
    return PaymentStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => PaymentStatus.pending,
    );
  }
}
