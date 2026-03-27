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
  String get clientLabel {
    switch (this) {
      case OrderStatus.newOrder:
        return 'ОФОРМЛЕН';
      case OrderStatus.accepted:
        return 'ПРИНЯТ';
      case OrderStatus.inProduction:
        return 'ПОШИВ';
      case OrderStatus.ready:
        return 'ГОТОВ';
      case OrderStatus.completed:
        return 'ЗАВЕРШЕН';
      case OrderStatus.cancelled:
        return 'ОТМЕНЕН';
    }
  }

  String get panelLabel {
    switch (this) {
      case OrderStatus.newOrder:
        return 'НОВЫЙ';
      case OrderStatus.accepted:
        return 'ПРИНЯТ';
      case OrderStatus.inProduction:
        return 'В ЦЕХЕ';
      case OrderStatus.ready:
        return 'ГОТОВ';
      case OrderStatus.completed:
        return 'ЗАВЕРШЕН';
      case OrderStatus.cancelled:
        return 'ОТМЕНЕН';
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

  String get productionActionLabel {
    switch (this) {
      case OrderStatus.accepted:
        return 'ВЗЯТЬ В ПОШИВ';
      case OrderStatus.inProduction:
        return 'ЗАВЕРШИТЬ';
      case OrderStatus.newOrder:
        return 'ПРИНЯТЬ';
      case OrderStatus.ready:
        return 'ГОТОВО';
      case OrderStatus.completed:
        return 'ЗАВЕРШЕН';
      case OrderStatus.cancelled:
        return 'ОТМЕНЕН';
    }
  }

  String get roleDescription {
    switch (this) {
      case OrderStatus.newOrder:
        return 'Новый заказ ожидает подтверждения франчайзи.';
      case OrderStatus.accepted:
        return 'Заказ подтвержден и передан в очередь цеха.';
      case OrderStatus.inProduction:
        return 'Изделие находится в пошиве и сборке.';
      case OrderStatus.ready:
        return 'Изделие готово и доступно к выдаче клиенту.';
      case OrderStatus.completed:
        return 'Заказ успешно завершен.';
      case OrderStatus.cancelled:
        return 'Заказ отменен.';
    }
  }

  String get timelineTitle {
    switch (this) {
      case OrderStatus.newOrder:
        return 'Заказ оформлен';
      case OrderStatus.accepted:
        return 'Заказ принят';
      case OrderStatus.inProduction:
        return 'Пошив начат';
      case OrderStatus.ready:
        return 'Заказ готов';
      case OrderStatus.completed:
        return 'Заказ завершен';
      case OrderStatus.cancelled:
        return 'Заказ отменен';
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
