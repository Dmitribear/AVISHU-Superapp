import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/domain/enums/product_status.dart';
import '../../features/products/domain/models/product_model.dart';

class ProductSeeder {
  static Future<void> addSingleProduct() async {
    final firestore = FirebaseFirestore.instance;
    final repo = ProductRepository(firestore: firestore);
    final now = DateTime.now();

    final products = [
      ProductModel(
        id: 'avishu-dress-zeta',
        name: 'Dress ZETA',
        slug: 'dress-zeta',
        description: 'Архитектурное платье в стиле брутального минимализма AVISHU. Чистота линий и плотность сатина.',
        shortDescription: 'Платье-футляр, плотный сатин, архитектурный крой.',
        category: 'dresses',
        material: 'Плотный сатин / подкладка вискоза',
        silhouette: 'Structured column',
        atelierNote: 'Индивидуальный пошив в ателье AVISHU 3-5 дней.',
        sections: const ['Новинки', 'Платья'],
        colors: const ['Черный'],
        sizes: const ['S', 'M', 'L'],
        defaultColor: 'Черный',
        defaultSize: 'S',
        specifications: const [
          ProductSpecEntry(label: 'Силуэт', value: 'Structured column'),
          ProductSpecEntry(label: 'Ткань', value: 'Плотный сатин 100%'),
        ],
        care: const ['Сухая чистка.', 'Гладить с паром.'],
        price: 38900,
        currency: 'KZT',
        coverImage: 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
        gallery: const [
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: true,
        defaultProductionDays: 4,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'avishu-suit-kappa',
        name: 'Suit KAPPA',
        slug: 'suit-kappa',
        description: 'Структурный костюм оверсайз. Прямые линии, премиальная шерсть. Бескомпромиссный минимализм.',
        shortDescription: 'Костюм оверсайз, премиальная шерсть.',
        category: 'suits',
        material: 'Шерсть 80% / ПА 20%',
        silhouette: 'Oversized boxy',
        atelierNote: 'Пошив по предзаказу 5-7 дней.',
        sections: const ['Новинки', 'Костюмы'],
        colors: const ['Антрацит'],
        sizes: const ['XS', 'S', 'M', 'L'],
        defaultColor: 'Антрацит',
        defaultSize: 'M',
        specifications: const [
          ProductSpecEntry(label: 'Силуэт', value: 'Oversized boxy'),
          ProductSpecEntry(label: 'Ткань', value: 'Шерсть 80%'),
        ],
        care: const ['Только химчистка.'],
        price: 72000,
        currency: 'KZT',
        coverImage: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
        gallery: const [
          'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: true,
        defaultProductionDays: 7,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'avishu-coat-omega',
        name: 'Coat OMEGA',
        slug: 'coat-omega',
        description: 'Пальто-макси с четким плечом. Массивный силуэт, глубокие карманы. Идеально для брутального образа.',
        shortDescription: 'Пальто-макси, шерсть, четкое плечо.',
        category: 'outerwear',
        material: '100% Мериносовая шерсть',
        silhouette: 'Maxi straight',
        atelierNote: 'Пошив по меркам 6-8 дней.',
        sections: const ['Новинки', 'Верхняя одежда'],
        colors: const ['Черный'],
        sizes: const ['S', 'M', 'L', 'XL'],
        defaultColor: 'Черный',
        defaultSize: 'M',
        specifications: const [
          ProductSpecEntry(label: 'Силуэт', value: 'Maxi straight'),
          ProductSpecEntry(label: 'Ткань', value: 'Меринос 100%'),
        ],
        care: const ['Профессиональная чистка.'],
        price: 98000,
        currency: 'KZT',
        coverImage: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
        gallery: const [
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: false,
        defaultProductionDays: 0,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    try {
      for (final p in products) {
        await repo.upsertProduct(p);
        dev.log('ТОВАР ДОБАВЛЕН УСПЕШНО: ${p.name}');
      }
    } catch (e) {
      dev.log('ОШИБКА ПРИ ДОБАВЛЕНИИ: $e');
    }
  }
}
