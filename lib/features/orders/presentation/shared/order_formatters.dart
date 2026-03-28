String formatCurrency(double value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < whole.length; index++) {
    final reverseIndex = whole.length - index;
    buffer.write(whole[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} ₸';
}

String formatTimelineDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.${value.year}  $hour:$minute';
}
