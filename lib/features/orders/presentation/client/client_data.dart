import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/enums/order_status.dart';

enum ClientTab { dashboard, collections, archive, profile }

enum ClientView { root, product, checkout, payment, tracking }

class ProductSpec {
  final String label;
  final String value;

  const ProductSpec({required this.label, required this.value});
}

class SizeGuideColumn {
  final String size;
  final String chest;
  final String waist;
  final String hips;

  const SizeGuideColumn({
    required this.size,
    required this.chest,
    required this.waist,
    required this.hips,
  });
}

class SizeGuideGroup {
  final String title;
  final String unitLabel;
  final List<SizeGuideColumn> columns;

  const SizeGuideGroup({
    required this.title,
    required this.unitLabel,
    required this.columns,
  });
}

class CatalogProduct {
  final String id;
  final String title;
  final String category;
  final List<String> sections;
  final String season;
  final String material;
  final String silhouette;
  final String sku;
  final double price;
  final bool preorder;
  final bool inStock;
  final String shortDescription;
  final String description;
  final List<String> colors;
  final String defaultColor;
  final List<String> sizes;
  final String defaultSize;
  final List<String> imageUrls;
  final List<ProductSpec> specifications;
  final List<String> care;
  final String atelierNote;

  const CatalogProduct({
    required this.id,
    required this.title,
    required this.category,
    required this.sections,
    required this.season,
    required this.material,
    required this.silhouette,
    required this.sku,
    required this.price,
    required this.preorder,
    required this.inStock,
    required this.shortDescription,
    required this.description,
    required this.colors,
    required this.defaultColor,
    required this.sizes,
    required this.defaultSize,
    required this.imageUrls,
    required this.specifications,
    required this.care,
    required this.atelierNote,
  });

  String get sizeLabel => defaultSize;

  bool get isNew => sections.contains('Новинки');

  String get availabilityLabel {
    if (inStock) {
      return 'В наличии';
    }
    if (preorder) {
      return 'Индивидуальный пошив 2-4 дня';
    }
    return 'Ожидаем поступление';
  }
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

const catalogSections = <String>[
  'Новинки',
  'Верхняя одежда',
  'Кардиганы и кофты',
  'Костюмы',
  'База',
  'Брюки',
  'Юбки',
  'Лето',
  'Зима',
  'Весна',
];

const baseSizeGuide = SizeGuideGroup(
  title: 'Базовые размеры',
  unitLabel: 'см',
  columns: [
    SizeGuideColumn(
      size: 'XS (40)',
      chest: '80-83',
      waist: '62-65',
      hips: '88-91',
    ),
    SizeGuideColumn(
      size: 'S (42)',
      chest: '84-87',
      waist: '66-69',
      hips: '92-95',
    ),
    SizeGuideColumn(
      size: 'M (44)',
      chest: '88-91',
      waist: '70-73',
      hips: '96-99',
    ),
    SizeGuideColumn(
      size: 'L (46)',
      chest: '92-95',
      waist: '74-77',
      hips: '100-103',
    ),
    SizeGuideColumn(
      size: 'XL (48)',
      chest: '96-99',
      waist: '78-81',
      hips: '104-107',
    ),
    SizeGuideColumn(
      size: '2XL (50)',
      chest: '100-103',
      waist: '82-85',
      hips: '108-111',
    ),
    SizeGuideColumn(
      size: '3XL (52)',
      chest: '104-107',
      waist: '86-89',
      hips: '112-115',
    ),
  ],
);

const plusSizeGuide = SizeGuideGroup(
  title: 'Размеры Plus (+20% к стоимости)',
  unitLabel: 'см',
  columns: [
    SizeGuideColumn(
      size: '4XL (54)',
      chest: '108-111',
      waist: '90-93',
      hips: '116-119',
    ),
    SizeGuideColumn(
      size: '5XL (56)',
      chest: '112-115',
      waist: '94-97',
      hips: '120-123',
    ),
    SizeGuideColumn(
      size: '6XL (58)',
      chest: '116-119',
      waist: '98-101',
      hips: '124-127',
    ),
  ],
);

const catalog = <CatalogProduct>[
  CatalogProduct(
    id: 'she-skirt',
    title: 'ЮБКА SHE',
    category: 'Юбки',
    sections: ['Новинки', 'Юбки', 'Лето', 'База'],
    season: 'Лето',
    material: 'Эко-кожа / подкладка вискоза',
    silhouette: 'A-line midi',
    sku: 'AV-SHE-24031',
    price: 30500,
    preorder: true,
    inStock: false,
    shortDescription:
        'Миди-юбка с мягким объемом и премиальной посадкой для летних капсул.',
    description:
        'Юбка SHE построена на чистой линии талии и мягком, собранном объеме. '
        'Материал держит форму, но остается пластичным в движении. Модель легко '
        'работает в дневных капсулах и вечерних образах, а при отсутствии на складе '
        'может быть выполнена ателье под заказ в течение 2-4 дней.',
    colors: ['Кофе', 'Черный'],
    defaultColor: 'Кофе',
    sizes: ['XS', 'S', 'M', 'L', 'XL', '2XL'],
    defaultSize: 'XS',
    imageUrls: [
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Силуэт', value: 'A-line midi'),
      ProductSpec(label: 'Посадка', value: 'Высокая талия'),
      ProductSpec(label: 'Материал', value: 'Эко-кожа с матовой фактурой'),
      ProductSpec(label: 'Производство', value: 'Алматы, AVISHU Atelier'),
    ],
    care: [
      'Деликатная сухая чистка.',
      'Не использовать машинную стирку и отбеливание.',
      'Хранить на мягкой вешалке или в чехле.',
    ],
    atelierNote:
        'Если нужного размера нет в наличии, изделие будет отшито индивидуально.',
  ),
  CatalogProduct(
    id: 'line-suit',
    title: 'КОСТЮМ LINE',
    category: 'Костюмы',
    sections: ['Новинки', 'Костюмы', 'Весна'],
    season: 'Весна',
    material: 'Костюмная шерсть super 120s',
    silhouette: 'Relaxed tailoring',
    sku: 'AV-LIN-24014',
    price: 68200,
    preorder: false,
    inStock: true,
    shortDescription:
        'Свободный костюм с архитектурным плечом и мягкой линией талии.',
    description:
        'LINE объединяет острую графику плеча и расслабленную посадку брюк, '
        'создавая цельный образ для офиса, съемок и вечерних встреч. Жакет и брюки '
        'можно носить вместе или интегрировать в базовый гардероб по отдельности.',
    colors: ['Графит', 'Молочный'],
    defaultColor: 'Графит',
    sizes: ['S', 'M', 'L', 'XL'],
    defaultSize: 'M',
    imageUrls: [
      'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Комплект', value: 'Жакет + брюки'),
      ProductSpec(label: 'Силуэт', value: 'Relaxed tailoring'),
      ProductSpec(label: 'Подкладка', value: 'Вискоза'),
      ProductSpec(label: 'Роль', value: 'Капсульный костюм на каждый день'),
    ],
    care: [
      'Рекомендуется сухая чистка.',
      'Гладить с паром на низкой температуре.',
      'Хранить жакет на широких плечиках.',
    ],
    atelierNote:
        'Возможна посадка по росту и длине рукава в рамках ателье AVISHU.',
  ),
  CatalogProduct(
    id: 'lune-cardigan',
    title: 'КАРДИГАН LUNE',
    category: 'Кардиганы и кофты',
    sections: ['Новинки', 'Кардиганы и кофты', 'Весна', 'База'],
    season: 'Весна',
    material: 'Хлопок / кашемир',
    silhouette: 'Soft volume',
    sku: 'AV-LUN-24022',
    price: 26800,
    preorder: false,
    inStock: true,
    shortDescription:
        'Мягкий кардиган свободной посадки с аккуратной линией плеч и пуговицами в тон.',
    description:
        'LUNE создан для многослойных образов и переходного сезона. Он комфортно '
        'садится на футболку, платье или топ и сохраняет чистую, дорогую линию даже '
        'в расслабленных комплектах.',
    colors: ['Сливочный', 'Черный', 'Серый меланж'],
    defaultColor: 'Сливочный',
    sizes: ['XS', 'S', 'M', 'L'],
    defaultSize: 'S',
    imageUrls: [
      'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Состав', value: '90% хлопок, 10% кашемир'),
      ProductSpec(label: 'Посадка', value: 'Свободная'),
      ProductSpec(label: 'Детали', value: 'Роговые пуговицы, мягкий кант'),
      ProductSpec(label: 'Назначение', value: 'База и layering'),
    ],
    care: [
      'Ручная стирка в прохладной воде.',
      'Сушить на горизонтальной поверхности.',
      'Не выкручивать и не сушить в машине.',
    ],
    atelierNote:
        'Кардиган отлично сочетается с юбками миди, костюмными брюками и денимом.',
  ),
  CatalogProduct(
    id: 'arc-trousers',
    title: 'БРЮКИ ARC',
    category: 'Брюки',
    sections: ['Брюки', 'База', 'Лето', 'Новинки'],
    season: 'Лето',
    material: 'Хлопок с эластаном',
    silhouette: 'Wide leg',
    sku: 'AV-ARC-24009',
    price: 24200,
    preorder: false,
    inStock: true,
    shortDescription:
        'Широкие брюки с высокой посадкой и мягкой складкой по переду.',
    description:
        'ARC работают как ежедневная база и как часть капсульного костюма. '
        'Модель вытягивает силуэт, визуально удлиняет ноги и сохраняет строгую '
        'линию даже в расслабленной посадке.',
    colors: ['Песочный', 'Черный', 'Белый'],
    defaultColor: 'Песочный',
    sizes: ['XS', 'S', 'M', 'L', 'XL'],
    defaultSize: 'S',
    imageUrls: [
      'https://images.unsplash.com/photo-1495385794356-15371f348c31?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1502716119720-b23a93e5fe1b?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Посадка', value: 'Высокая'),
      ProductSpec(label: 'Силуэт', value: 'Wide leg'),
      ProductSpec(label: 'Длина', value: 'Full length'),
      ProductSpec(label: 'Детали', value: 'Боковые карманы, стрелка'),
    ],
    care: [
      'Деликатная стирка при 30°C.',
      'Сушить в расправленном виде.',
      'Гладить с изнанки через ткань.',
    ],
    atelierNote:
        'Для идеальной длины можно выполнить подгонку под каблук или плоский ход.',
  ),
  CatalogProduct(
    id: 'frame-top',
    title: 'ТОП FRAME',
    category: 'База',
    sections: ['Новинки', 'База', 'Лето'],
    season: 'Лето',
    material: 'Хлопок премиум',
    silhouette: 'Oversized tee',
    sku: 'AV-FRM-24018',
    price: 18200,
    preorder: false,
    inStock: true,
    shortDescription:
        'Чистый oversize-топ для капсулы на каждый день и для многослойных сетов.',
    description:
        'FRAME вдохновлен лаконичными архивными футболками и адаптирован под '
        'современную посадку. Плотный хлопок красиво держит объем и работает как '
        'фон для сложных аксессуаров и акцентных юбок.',
    colors: ['Черный', 'Молочный'],
    defaultColor: 'Черный',
    sizes: ['XS', 'S', 'M', 'L', 'XL', '2XL'],
    defaultSize: 'M',
    imageUrls: [
      'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Состав', value: '100% хлопок'),
      ProductSpec(label: 'Крой', value: 'Oversized'),
      ProductSpec(label: 'Плечо', value: 'Спущенное'),
      ProductSpec(label: 'Комбинации', value: 'Юбки, брюки, костюмы'),
    ],
    care: [
      'Стирка при 30°C наизнанку.',
      'Не использовать агрессивные отбеливатели.',
      'Сушить вдали от прямого солнца.',
    ],
    atelierNote:
        'Топ рассчитан на ежедневную носку и сочетается с любой капсулой AVISHU.',
  ),
  CatalogProduct(
    id: 'mono-coat',
    title: 'ПАЛЬТО MONO',
    category: 'Верхняя одежда',
    sections: ['Верхняя одежда', 'Зима'],
    season: 'Зима',
    material: 'Шерсть / кашемир',
    silhouette: 'Longline coat',
    sku: 'AV-MON-24001',
    price: 89500,
    preorder: true,
    inStock: false,
    shortDescription:
        'Длинное пальто прямого кроя с чистым силуэтом и акцентной линией плеч.',
    description:
        'MONO создано как инвестиционная вещь сезона. Плотная шерстяная ткань '
        'сохраняет форму, а минималистичная конструкция делает пальто универсальным '
        'для дневных и вечерних выходов. Доступен индивидуальный пошив по длине.',
    colors: ['Графит', 'Черный'],
    defaultColor: 'Графит',
    sizes: ['S', 'M', 'L', 'XL'],
    defaultSize: 'M',
    imageUrls: [
      'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
    ],
    specifications: [
      ProductSpec(label: 'Длина', value: 'Maxi'),
      ProductSpec(label: 'Утепление', value: 'Плотная шерстяная основа'),
      ProductSpec(label: 'Застежка', value: 'Скрытая кнопка'),
      ProductSpec(label: 'Силуэт', value: 'Прямой, собранный'),
    ],
    care: [
      'Только профессиональная химчистка.',
      'Проветривать между выходами.',
      'Использовать защитный чехол при хранении.',
    ],
    atelierNote:
        'Для пальто доступна коррекция длины и посадки в ателье после примерки.',
  ),
];

const archiveCollections = <ArchiveCollection>[
  ArchiveCollection(
    year: '2026',
    season: 'SPRING-SUMMER',
    title: 'SOFT GEOMETRY',
    released: true,
  ),
  ArchiveCollection(
    year: '2025',
    season: 'FALL-WINTER',
    title: 'MONOCHROME SIGNAL',
    released: false,
  ),
  ArchiveCollection(
    year: '2024',
    season: 'SPRING-SUMMER',
    title: 'KINETIC SILENCE',
    released: false,
  ),
  ArchiveCollection(
    year: '2023',
    season: 'ANTHOLOGY',
    title: 'AVISHU ARCHIVE 01',
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

OrderModel? resolveTrackedOrder(
  List<OrderModel> orders,
  String? latestOrderId,
) {
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
    if (order.status != OrderStatus.ready &&
        order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled) {
      return order;
    }
  }

  return orders.first;
}
