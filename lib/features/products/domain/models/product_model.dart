import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/firestore_parsing.dart';
import '../enums/product_status.dart';

class ProductSpecEntry {
  final String label;
  final String value;

  const ProductSpecEntry({required this.label, required this.value});

  factory ProductSpecEntry.fromMap(Map<String, dynamic> map) {
    return ProductSpecEntry(
      label: (map['label'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'value': value};
}

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String shortDescription;
  final String category;
  final String material;
  final String silhouette;
  final String atelierNote;
  final List<String> sections;
  final List<String> colors;
  final List<String> sizes;
  final String defaultColor;
  final String defaultSize;
  final List<ProductSpecEntry> specifications;
  final List<String> care;
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
    required this.shortDescription,
    required this.category,
    required this.material,
    required this.silhouette,
    required this.atelierNote,
    required this.sections,
    required this.colors,
    required this.sizes,
    required this.defaultColor,
    required this.defaultSize,
    required this.specifications,
    required this.care,
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

    final rawSpecs = data['specifications'];
    final specifications = rawSpecs is List
        ? rawSpecs
              .whereType<Map<String, dynamic>>()
              .map(ProductSpecEntry.fromMap)
              .toList()
        : <ProductSpecEntry>[];

    final care = stringListFromFirestoreValue(data['care']);
    final colors = stringListFromFirestoreValue(data['colors']);
    final sizes = stringListFromFirestoreValue(data['sizes']);
    final sections = stringListFromFirestoreValue(data['sections']);
    final description = stringFromFirestoreValue(data['description']);
    final rawShortDesc = stringFromFirestoreValue(data['shortDescription']);

    return ProductModel(
      id: stringFromFirestoreValue(data['id'], fallback: doc.id),
      name: stringFromFirestoreValue(data['name']),
      slug: stringFromFirestoreValue(data['slug'], fallback: doc.id),
      description: description,
      shortDescription: rawShortDesc.isNotEmpty
          ? rawShortDesc
          : _truncate(description, 110),
      category: stringFromFirestoreValue(data['category']),
      material: stringFromFirestoreValue(data['material']),
      silhouette: stringFromFirestoreValue(data['silhouette']),
      atelierNote: stringFromFirestoreValue(data['atelierNote']),
      sections: sections,
      colors: colors,
      sizes: sizes,
      defaultColor: stringFromFirestoreValue(
        data['defaultColor'],
        fallback: colors.isNotEmpty ? colors.first : '',
      ),
      defaultSize: stringFromFirestoreValue(
        data['defaultSize'],
        fallback: sizes.isNotEmpty ? sizes.first : '',
      ),
      specifications: specifications,
      care: care,
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
      'shortDescription': shortDescription,
      'category': category,
      'material': material,
      'silhouette': silhouette,
      'atelierNote': atelierNote,
      'sections': sections,
      'colors': colors,
      'sizes': sizes,
      'defaultColor': defaultColor,
      'defaultSize': defaultSize,
      'specifications': specifications.map((s) => s.toMap()).toList(),
      'care': care,
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

  static String _truncate(String text, int maxLength) {
    final compact = text.trim();
    if (compact.isEmpty) return '';
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength - 3).trim()}...';
  }
}
