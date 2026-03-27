String formatCurrency(double value) {
  return '\$${value.toStringAsFixed(0)}';
}

String formatTimelineDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.${value.year}  $hour:$minute';
}
