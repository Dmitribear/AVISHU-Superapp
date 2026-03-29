import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/products/data/product_repository.dart';
import '../../features/products/domain/enums/product_status.dart';
import '../../features/products/domain/models/product_model.dart';

class ProductSeeder {
  static const _retiredProductIds = <String>[
    'avishu-dress-zeta',
    'avishu-suit-kappa',
    'avishu-coat-omega',
  ];

  static Future<void> addSingleProduct() async {
    final firestore = FirebaseFirestore.instance;
    final repository = ProductRepository(firestore: firestore);
    final now = DateTime.now();

    for (final productId in _retiredProductIds) {
      await repository.deleteProduct(productId);
    }

    final product = ProductModel(
      id: 'cardigan-lune',
      name: 'Cardigan LUNE',
      slug: 'cardigan-lune',
      description:
          'Мягкий кардиган из хлопка и кашемира для спокойного layering-сценария AVISHU. Прямой крой, вытянутый силуэт и чистая база на каждый день.',
      shortDescription:
          'Прямой кардиган из хлопка и кашемира для базового гардероба.',
      category: 'cardigans',
      material: 'Хлопок 70% / кашемир 30%',
      silhouette: 'Straight relaxed',
      atelierNote: 'В наличии. Отправка на следующий день.',
      sections: const <String>['Кардиганы и кофты', 'База'],
      colors: const <String>['Экрю', 'Серый', 'Пыльно-розовый'],
      sizes: const <String>['XS', 'S', 'M', 'L'],
      defaultColor: 'Экрю',
      defaultSize: 'S',
      specifications: const <ProductSpecEntry>[
        ProductSpecEntry(label: 'Силуэт', value: 'Straight relaxed'),
        ProductSpecEntry(label: 'Длина', value: '82 см (размер M)'),
        ProductSpecEntry(label: 'Артикул', value: 'CDG-LUNE'),
        ProductSpecEntry(label: 'Состав', value: 'Хлопок 70% / кашемир 30%'),
      ],
      care: const <String>[
        'Ручная стирка при 30°C.',
        'Сушить в горизонтальном положении.',
        'Не выкручивать.',
        'Хранить сложенным.',
      ],
      price: 26800,
      currency: 'KZT',
      coverImage:
          'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
      gallery: const <String>[
        'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?auto=format&fit=crop&w=1200&q=80',
      ],
      isPreorderAvailable: false,
      defaultProductionDays: 0,
      status: ProductStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await repository.upsertProduct(product);
      dev.log('Товар добавлен: ${product.name}');
    } catch (error) {
      dev.log('Не удалось добавить товар: $error');
    }
  }
}
