enum OrderStatus {
  newOrder('New'),
  accepted('Accepted'),
  inProduction('InProduction'),
  ready('Ready');

  final String value;
  const OrderStatus(this.value);

  factory OrderStatus.fromMap(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
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
        return 'ГОТОВО';
    }
  }

  String get panelLabel {
    switch (this) {
      case OrderStatus.newOrder:
        return 'NEW';
      case OrderStatus.accepted:
        return 'QUEUED';
      case OrderStatus.inProduction:
        return 'SEWING';
      case OrderStatus.ready:
        return 'READY';
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
        return 2;
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
        return 'Изделие готово и доступно клиенту.';
    }
  }

  double get progressValue {
    switch (this) {
      case OrderStatus.newOrder:
        return 0.25;
      case OrderStatus.accepted:
        return 0.55;
      case OrderStatus.inProduction:
        return 0.8;
      case OrderStatus.ready:
        return 1;
    }
  }
}
