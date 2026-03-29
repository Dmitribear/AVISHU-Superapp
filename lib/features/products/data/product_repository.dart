import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/product_status.dart';
import '../domain/models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Stream<List<ProductModel>> watchAllProducts() {
    return _products.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(ProductModel.fromFirestore).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  Stream<List<ProductModel>> watchActiveProducts() {
    return _products
        .where('status', isEqualTo: ProductStatus.active.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ProductModel.fromFirestore).toList()
                ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  Future<List<ProductModel>> fetchActiveProducts() async {
    final snapshot = await _products
        .where('status', isEqualTo: ProductStatus.active.value)
        .get();
    final products = snapshot.docs.map(ProductModel.fromFirestore).toList();
    products.sort((a, b) => a.name.compareTo(b.name));
    return products;
  }

  Future<ProductModel?> fetchById(String productId) async {
    final doc = await _products.doc(productId).get();
    if (!doc.exists) {
      return null;
    }
    return ProductModel.fromFirestore(doc);
  }

  Future<void> upsertProduct(ProductModel product) {
    return _products
        .doc(product.id)
        .set(product.toMap(), SetOptions(merge: true));
  }
}
