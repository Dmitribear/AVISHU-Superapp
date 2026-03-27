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
