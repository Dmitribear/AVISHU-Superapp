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
    );

    final catalogProduct = catalogProductFromFirestore(product);

    expect(catalogProduct.id, 'she-skirt');
    expect(catalogProduct.title, 'Skirt SHE Firestore');
    expect(catalogProduct.price, 35500);
    expect(catalogProduct.sections, contains('Юбки'));
    expect(catalogProduct.imageUrls.first, 'https://example.com/cover.jpg');
  });
}
