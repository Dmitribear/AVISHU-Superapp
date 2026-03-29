import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/presentation/client/client_data.dart';
import 'package:avishu/features/products/domain/enums/product_status.dart';
import 'package:avishu/features/products/domain/models/product_model.dart';

void main() {
  test('catalog adapter keeps firestore price and fallback metadata', () {
    final now = DateTime(2026, 3, 28);
    final product = ProductModel(
      id: 'she-skirt',
      name: 'Skirt SHE Firestore',
      slug: 'skirt-she',
      description: 'Firestore-backed premium skirt.',
      category: 'skirts',
      price: 35500,
      currency: 'KZT',
      coverImage: 'https://example.com/cover.jpg',
      gallery: const ['https://example.com/cover.jpg'],
      isPreorderAvailable: true,
      defaultProductionDays: 4,
      status: ProductStatus.active,
      createdAt: now,
      updatedAt: now,
      specifications: const [],
      care: const [],
      colors: const ['Black'],
      sizes: const ['S', 'M'],
      defaultColor: 'Black',
      defaultSize: 'S',
      isInStock: true,
      sizeAvailability: const {'S': false, 'M': true},
      sections: const ['Юбки'],
      silhouette: 'A-Line',
      material: 'Wool',
      atelierNote: '',
      shortDescription: 'Premium wool skirt.',
    );

    final catalogProduct = catalogProductFromFirestore(product);

    expect(catalogProduct.id, 'she-skirt');
    expect(catalogProduct.title, 'Skirt SHE Firestore');
    expect(catalogProduct.price, 35500);
    expect(catalogProduct.sections, contains('Юбки'));
    expect(catalogProduct.imageUrls.first, 'https://example.com/cover.jpg');
    expect(catalogProduct.inStock, isTrue);
    expect(catalogProduct.defaultSize, 'M');
    expect(catalogProduct.isSizeAvailable('S'), isFalse);
    expect(catalogProduct.isSizeAvailable('M'), isTrue);
    expect(catalogProduct.firstAvailableSize, 'M');
  });
}
