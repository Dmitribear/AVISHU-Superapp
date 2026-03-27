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
        return tr(language, ru: 'ОФОРМЛЕН', en: 'PLACED');
      case OrderStatus.accepted:
        return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED');
      case OrderStatus.inProduction:
        return tr(language, ru: 'ПОШИВ', en: 'IN PRODUCTION');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВ', en: 'READY');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED');
    }
  }

  String panelLabelFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(language, ru: 'НОВЫЙ', en: 'NEW');
      case OrderStatus.accepted:
        return tr(language, ru: 'ПРИНЯТ', en: 'ACCEPTED');
      case OrderStatus.inProduction:
        return tr(language, ru: 'В ЦЕХЕ', en: 'IN PRODUCTION');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВ', en: 'READY');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED');
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
        return tr(language, ru: 'ВЗЯТЬ В ПОШИВ', en: 'START PRODUCTION');
      case OrderStatus.inProduction:
        return tr(language, ru: 'ЗАВЕРШИТЬ', en: 'COMPLETE');
      case OrderStatus.newOrder:
        return tr(language, ru: 'ПРИНЯТЬ', en: 'ACCEPT');
      case OrderStatus.ready:
        return tr(language, ru: 'ГОТОВО', en: 'READY');
      case OrderStatus.completed:
        return tr(language, ru: 'ЗАВЕРШЕН', en: 'COMPLETED');
      case OrderStatus.cancelled:
        return tr(language, ru: 'ОТМЕНЕН', en: 'CANCELLED');
    }
  }

  String roleDescriptionFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(
          language,
          ru: 'Новый заказ ожидает подтверждения франчайзи.',
          en: 'A new order is waiting for franchisee confirmation.',
        );
      case OrderStatus.accepted:
        return tr(
          language,
          ru: 'Заказ подтвержден и передан в очередь цеха.',
          en: 'The order has been accepted and moved to the factory queue.',
        );
      case OrderStatus.inProduction:
        return tr(
          language,
          ru: 'Изделие находится в пошиве и сборке.',
          en: 'The garment is currently in tailoring and assembly.',
        );
      case OrderStatus.ready:
        return tr(
          language,
          ru: 'Изделие готово и доступно к выдаче клиенту.',
          en: 'The garment is ready for client handoff.',
        );
      case OrderStatus.completed:
        return tr(
          language,
          ru: 'Заказ успешно завершен.',
          en: 'The order has been completed successfully.',
        );
      case OrderStatus.cancelled:
        return tr(
          language,
          ru: 'Заказ отменен.',
          en: 'The order was cancelled.',
        );
    }
  }

  String timelineTitleFor(AppLanguage language) {
    switch (this) {
      case OrderStatus.newOrder:
        return tr(language, ru: 'Заказ оформлен', en: 'Order placed');
      case OrderStatus.accepted:
        return tr(language, ru: 'Заказ принят', en: 'Order accepted');
      case OrderStatus.inProduction:
        return tr(language, ru: 'Пошив начат', en: 'Production started');
      case OrderStatus.ready:
        return tr(language, ru: 'Заказ готов', en: 'Order ready');
      case OrderStatus.completed:
        return tr(language, ru: 'Заказ завершен', en: 'Order completed');
      case OrderStatus.cancelled:
        return tr(language, ru: 'Заказ отменен', en: 'Order cancelled');
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
