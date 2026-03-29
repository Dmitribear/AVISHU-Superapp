import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/product_status.dart';
import '../domain/models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

class ProductRepository {
  static const _retiredProductIds = <String>{
    'avishu-dress-zeta',
    'avishu-suit-kappa',
    'avishu-coat-omega',
  };

  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Stream<List<ProductModel>> watchAllProducts() {
    return _products.snapshots().map(
      (snapshot) =>
          _visibleProducts(snapshot.docs)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  Stream<List<ProductModel>> watchActiveProducts() {
    return _products
        .where('status', isEqualTo: ProductStatus.active.value)
        .snapshots()
        .map(
          (snapshot) =>
              _visibleProducts(snapshot.docs)
                ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  Future<List<ProductModel>> fetchActiveProducts() async {
    final snapshot = await _products
        .where('status', isEqualTo: ProductStatus.active.value)
        .get();
    final products = _visibleProducts(snapshot.docs);
    products.sort((a, b) => a.name.compareTo(b.name));
    return products;
  }

  Future<ProductModel?> fetchById(String productId) async {
    final doc = await _products.doc(productId).get();
    if (!doc.exists) {
      return null;
    }
    final product = ProductModel.fromFirestore(doc);
    if (_retiredProductIds.contains(product.id)) {
      return null;
    }
    return product;
  }

  Future<void> upsertProduct(ProductModel product) {
    return _products
        .doc(product.id)
        .set(product.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteProduct(String productId) {
    return _products.doc(productId).delete();
  }

  List<ProductModel> _visibleProducts(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map(ProductModel.fromFirestore)
        .where((product) => !_retiredProductIds.contains(product.id))
        .toList();
  }
}
