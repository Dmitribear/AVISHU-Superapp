import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/firestore_parsing.dart';
import '../enums/product_status.dart';

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String category;
  final double price;
  final String currency;
  final String coverImage;
  final List<String> gallery;
  final bool isPreorderAvailable;
  final int defaultProductionDays;
  final ProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    required this.price,
    required this.currency,
    required this.coverImage,
    required this.gallery,
    required this.isPreorderAvailable,
    required this.defaultProductionDays,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt =
        dateTimeFromFirestoreValue(data['createdAt']) ?? DateTime.now();
    final updatedAt =
        dateTimeFromFirestoreValue(data['updatedAt']) ?? createdAt;

    final gallery = stringListFromFirestoreValue(data['gallery']);
    final coverImage = stringFromFirestoreValue(
      data['coverImage'],
      fallback: gallery.isNotEmpty ? gallery.first : '',
    );

    return ProductModel(
      id: stringFromFirestoreValue(data['id'], fallback: doc.id),
      name: stringFromFirestoreValue(data['name']),
      slug: stringFromFirestoreValue(data['slug'], fallback: doc.id),
      description: stringFromFirestoreValue(data['description']),
      category: stringFromFirestoreValue(data['category']),
      price: doubleFromFirestoreValue(data['price']),
      currency: stringFromFirestoreValue(data['currency'], fallback: 'KZT'),
      coverImage: coverImage,
      gallery: gallery.isEmpty && coverImage.isNotEmpty
          ? <String>[coverImage]
          : gallery,
      isPreorderAvailable: boolFromFirestoreValue(data['isPreorderAvailable']),
      defaultProductionDays: intFromFirestoreValue(
        data['defaultProductionDays'],
      ),
      status: ProductStatus.fromMap(data['status'] as String?),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'category': category,
      'price': price,
      'currency': currency,
      'coverImage': coverImage,
      'gallery': gallery,
      'isPreorderAvailable': isPreorderAvailable,
      'defaultProductionDays': defaultProductionDays,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
