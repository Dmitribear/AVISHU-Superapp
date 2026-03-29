import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dateTimeFromFirestoreValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Timestamp? timestampFromDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return Timestamp.fromDate(value);
}

GeoPoint? geoPointFromFirestoreValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is GeoPoint) {
    return value;
  }
  if (value is Map) {
    final latitude = value['latitude'] ?? value['lat'];
    final longitude = value['longitude'] ?? value['lng'];
    if (latitude is num && longitude is num) {
      return GeoPoint(latitude.toDouble(), longitude.toDouble());
    }
  }
  return null;
}

double doubleFromFirestoreValue(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

int intFromFirestoreValue(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

String stringFromFirestoreValue(dynamic value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

bool boolFromFirestoreValue(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

List<String> stringListFromFirestoreValue(dynamic value) {
  if (value is Iterable) {
    return value.whereType<String>().toList();
  }
  return const <String>[];
}

Map<String, bool> stringBoolMapFromFirestoreValue(dynamic value) {
  if (value is Map) {
    final result = <String, bool>{};
    value.forEach((key, mapValue) {
      if (key is String && mapValue is bool) {
        result[key] = mapValue;
      }
    });
    return result;
  }
  return const <String, bool>{};
}
