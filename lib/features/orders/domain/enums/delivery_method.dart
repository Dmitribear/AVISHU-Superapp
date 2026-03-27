import '../../../../shared/i18n/app_localization.dart';

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
  String get label => labelFor(AppLanguage.russian);

  String labelFor(AppLanguage language) {
    switch (this) {
      case DeliveryMethod.courier:
        return tr(language, ru: 'Курьер', en: 'Courier');
      case DeliveryMethod.pickup:
        return tr(language, ru: 'Самовывоз', en: 'Pickup');
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
