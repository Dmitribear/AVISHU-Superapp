import '../../../orders/domain/models/order_model.dart';

enum ClientTab { dashboard, collections, archive, profile }

enum ClientView { root, product, checkout, payment, tracking }

class CatalogProduct {
  final String title;
  final String material;
  final String sizeLabel;
  final String sku;
  final double price;
  final bool preorder;
  final String description;

  const CatalogProduct({
    required this.title,
    required this.material,
    required this.sizeLabel,
    required this.sku,
    required this.price,
    required this.preorder,
    required this.description,
  });
}

class ArchiveCollection {
  final String year;
  final String season;
  final String title;
  final bool released;

  const ArchiveCollection({
    required this.year,
    required this.season,
    required this.title,
    required this.released,
  });
}

const catalog = <CatalogProduct>[
  CatalogProduct(
    title: 'STRUCTURED OVERCOAT',
    material: '100% ШЕРСТЬ',
    sizeLabel: 'SIZE 42',
    sku: 'AV-2024-00192',
    price: 840,
    preorder: true,
    description:
        'Пальто структурированного кроя из плотной шерстяной ткани. Острые лацканы и архитектурный силуэт продолжают язык AVISHU.',
  ),
  CatalogProduct(
    title: 'RAW DENIM JACKET',
    material: '14.5OZ SELVEDGE',
    sizeLabel: 'SIZE L',
    sku: 'AV-2024-00082',
    price: 420,
    preorder: false,
    description:
        'Тяжелый деним с индустриальной отделкой и архивной посадкой. Вещь для витрины и быстрых live-заказов.',
  ),
  CatalogProduct(
    title: 'M-65 FIELD JACKET',
    material: 'TECHNICAL COTTON',
    sizeLabel: 'SIZE M',
    sku: 'AV-2024-00071',
    price: 610,
    preorder: false,
    description:
        'Архивная полевая куртка с минималистичной геометрией, жесткой линией плеч и чистой графикой швов.',
  ),
];

const archiveCollections = <ArchiveCollection>[
  ArchiveCollection(
    year: '2024',
    season: 'FALL-WINTER',
    title: 'BRUTALIST TENDENCY',
    released: true,
  ),
  ArchiveCollection(
    year: '2023',
    season: 'SPRING-SUMMER',
    title: 'KINETIC MONOLITH',
    released: false,
  ),
  ArchiveCollection(
    year: '2023',
    season: 'FALL-WINTER',
    title: 'CONCRETE SHADOWS',
    released: false,
  ),
  ArchiveCollection(
    year: '2022',
    season: 'ANTHOLOGY',
    title: 'GENESIS: BLACK',
    released: false,
  ),
];

final dateOptions = <DateTime>[
  DateTime(2026, 10, 12),
  DateTime(2026, 10, 18),
  DateTime(2026, 10, 24),
  DateTime(2026, 11, 2),
  DateTime(2026, 11, 8),
];

String monthShort(int month) {
  const months = [
    'ЯНВ',
    'ФЕВ',
    'МАР',
    'АПР',
    'МАЙ',
    'ИЮН',
    'ИЮЛ',
    'АВГ',
    'СЕН',
    'ОКТ',
    'НОЯ',
    'ДЕК',
  ];
  return months[month - 1];
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

OrderModel? resolveTrackedOrder(List<OrderModel> orders, String? latestOrderId) {
  if (orders.isEmpty) {
    return null;
  }

  if (latestOrderId != null) {
    for (final order in orders) {
      if (order.id == latestOrderId) {
        return order;
      }
    }
  }

  for (final order in orders) {
    if (order.status.value != 'Ready') {
      return order;
    }
  }

  return orders.first;
}
