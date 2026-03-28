import '../../../../shared/i18n/app_localization.dart';

enum OrderStatus {
  newOrder('new', legacyValues: ['New']),
  accepted('accepted', legacyValues: ['Accepted']),
  inProduction('in_production', legacyValues: ['InProduction']),
  ready('ready', legacyValues: ['Ready']),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  final List<String> legacyValues;

  const OrderStatus(this.value, {this.legacyValues = const <String>[]});

  factory OrderStatus.fromMap(String value) {
    final normalized = value.trim().toLowerCase();
    return OrderStatus.values.firstWhere(
      (status) =>
          status.value == normalized ||
          status.legacyValues.any(
            (legacyValue) => legacyValue.toLowerCase() == normalized,
          ),
      orElse: () => OrderStatus.newOrder,
    );
  }
}

extension OrderStatusX on OrderStatus {
  String get clientLabel => clientLabelFor(AppLanguage.russian);

  String get panelLabel => panelLabelFor(AppLanguage.russian);

  String get productionActionLabel =>
      productionActionLabelFor(AppLanguage.russian);

  String get roleDescription => roleDescriptionFor(AppLanguage.russian);

  String get timelineTitle => timelineTitleFor(AppLanguage.russian);

  String clientLabelFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(language, ru: 'ОФОРМЛЕН', en: 'PLACED', kk: 'ТАПСЫРЫС БЕРІЛДІ');
      case OrderStatus.accepted:
        return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED', kk: 'ҚАБЫЛДАНДЫ');
      case OrderStatus.inProduction:
        return tr(language, ru: 'ПОШИВ', en: 'IN PRODUCTION', kk: 'ТІГУ');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВ', en: 'READY', kk: 'ДАЙЫН');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED', kk: 'АЯҚТАЛДЫ');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED', kk: 'БАС ТАРТЫЛДЫ');
    }
  }

  String panelLabelFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(language, ru: 'НОВЫЙ', en: 'NEW', kk: 'ЖАҢА');
      case OrderStatus.accepted:
        return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED', kk: 'ҚАБЫЛДАНДЫ');
      case OrderStatus.inProduction:
        return tr(language, ru: 'В ЦЕХЕ', en: 'IN PRODUCTION', kk: 'ЦЕХТЕ');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВ', en: 'READY', kk: 'ДАЙЫН');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED', kk: 'АЯҚТАЛДЫ');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED', kk: 'БАС ТАРТЫЛДЫ');
    }
  }

  int get clientStage {
    switch (this) {
      case OrderStatus.newOrder:
        return 0;
      case OrderStatus.accepted:
      case OrderStatus.inProduction:
        return 1;
      case OrderStatus.ready:
      case OrderStatus.completed:
        return 2;
      case OrderStatus.cancelled:
        return 0;
    }
  }

  String productionActionLabelFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.accepted:
        return tr(language, ru: 'ВЗЯТЬ В ПОШИВ', en: 'START PRODUCTION', kk: 'ТІГУДІ БАСТАУ');
      case OrderStatus.inProduction:
        return tr(language, ru: 'ЗАВЕРШИТЬ', en: 'COMPLETE', kk: 'АЯҚТАУ');
      case OrderStatus.newOrder:
        return tr(language, ru: 'ПРИНЯТЬ', en: 'ACCEPT', kk: 'ҚАБЫЛДАУ');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВО', en: 'READY', kk: 'ДАЙЫН');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED', kk: 'АЯҚТАЛДЫ');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED', kk: 'БАС ТАРТЫЛДЫ');
    }
  }

  String roleDescriptionFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(
          language,
          ru: 'Новый заказ ожидает подтверждения франчайзи.',
          en: 'A new order is waiting for franchisee confirmation.',
          kk: 'Жаңа тапсырыс франчайзидің растауын күтуде.',
        );
      case OrderStatus.accepted:
        return tr(
          language,
          ru: 'Заказ подтвержден и передан в очередь цеха.',
          en: 'The order has been accepted and moved to the factory queue.',
          kk: 'Тапсырыс расталды және цех кезегіне жіберілді.',
        );
      case OrderStatus.inProduction:
        return tr(
          language,
          ru: 'Изделие находится в пошиве и сборке.',
          en: 'The garment is currently in tailoring and assembly.',
          kk: 'Бұйым тігілу және жиналу үстінде.',
        );
      case OrderStatus.ready:
        return tr(
          language,
          ru: 'Изделие готово и доступно к выдаче клиенту.',
          en: 'The garment is ready for client handoff.',
          kk: 'Бұйым дайын және клиентке беруге болады.',
        );
      case OrderStatus.completed:
        return tr(
          language,
          ru: 'Заказ успешно завершен.',
          en: 'The order has been completed successfully.',
          kk: 'Тапсырыс сәтті аяқталды.',
        );
      case OrderStatus.cancelled:
        return tr(
          language,
          ru: 'Заказ отменен.',
          en: 'The order was cancelled.',
          kk: 'Тапсырыс тоқтатылды.',
        );
    }
  }

  String timelineTitleFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(language, ru: 'Заказ оформлен', en: 'Order placed', kk: 'Тапсырыс берілді');
      case OrderStatus.accepted:
        return tr(language, ru: 'Заказ принят', en: 'Order accepted', kk: 'Тапсырыс қабылданды');
      case OrderStatus.inProduction:
        return tr(language, ru: 'Пошив начат', en: 'Production started', kk: 'Тігу басталды');
      case OrderStatus.ready:
        return tr(language, ru: 'Заказ готов', en: 'Order ready', kk: 'Тапсырыс дайын');
      case OrderStatus.completed:
        return tr(language, ru: 'Заказ завершен', en: 'Order completed', kk: 'Тапсырыс аяқталды');
      case OrderStatus.cancelled:
        return tr(language, ru: 'Заказ отменен', en: 'Order cancelled', kk: 'Тапсырыс тоқтатылды');
    }
  }

  double get progressValue {
    switch (this) {
      case OrderStatus.newOrder:
        return 0.2;
      case OrderStatus.accepted:
        return 0.45;
      case OrderStatus.inProduction:
        return 0.75;
      case OrderStatus.ready:
        return 0.95;
      case OrderStatus.completed:
        return 1;
      case OrderStatus.cancelled:
        return 0.05;
    }
  }
}
