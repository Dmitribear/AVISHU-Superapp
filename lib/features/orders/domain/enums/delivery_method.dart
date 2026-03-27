enum DeliveryMethod {
  courier('courier'),
  pickup('pickup');

  final String value;
  const DeliveryMethod(this.value);

  factory DeliveryMethod.fromMap(String? value) {
    return DeliveryMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => DeliveryMethod.courier,
    );
  }
}

extension DeliveryMethodX on DeliveryMethod {
  String get label {
    switch (this) {
      case DeliveryMethod.courier:
        return 'Курьер';
      case DeliveryMethod.pickup:
        return 'Самовывоз';
    }
  }

  double get fee {
    switch (this) {
      case DeliveryMethod.courier:
        return 25;
      case DeliveryMethod.pickup:
        return 0;
    }
  }
}
