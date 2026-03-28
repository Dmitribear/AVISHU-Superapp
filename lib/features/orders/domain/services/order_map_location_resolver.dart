import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/delivery_method.dart';

class OrderRouteLocations {
  final GeoPoint originLocation;
  final GeoPoint destinationLocation;

  const OrderRouteLocations({
    required this.originLocation,
    required this.destinationLocation,
  });
}

class OrderMapLocationResolver {
  static final Map<String, GeoPoint> _cityCenters = <String, GeoPoint>{
    'almaty': const GeoPoint(43.238949, 76.889709),
    'алматы': const GeoPoint(43.238949, 76.889709),
    'astana': const GeoPoint(51.169392, 71.449074),
    'астана': const GeoPoint(51.169392, 71.449074),
    'shymkent': const GeoPoint(42.3417, 69.5901),
    'шымкент': const GeoPoint(42.3417, 69.5901),
    'atyrau': const GeoPoint(47.0945, 51.9238),
    'атырау': const GeoPoint(47.0945, 51.9238),
  };

  static final GeoPoint _fallbackCityCenter = _cityCenters['almaty']!;
  static final GeoPoint _almatyAtelier = const GeoPoint(43.2331, 76.9569);
  static final GeoPoint _almatyPickupHub = const GeoPoint(43.2185, 76.9277);

  static OrderRouteLocations resolveRoute({
    required DeliveryMethod deliveryMethod,
    required String city,
    required String address,
    String apartment = '',
  }) {
    final normalizedCity = _normalize(city);
    final baseCity = _resolveCityCenter(normalizedCity);
    final origin = _resolveOrigin(deliveryMethod, normalizedCity, baseCity);
    final destination = _resolveDestination(
      deliveryMethod: deliveryMethod,
      normalizedCity: normalizedCity,
      address: address,
      apartment: apartment,
      baseCity: baseCity,
    );

    return OrderRouteLocations(
      originLocation: origin,
      destinationLocation: destination,
    );
  }

  static GeoPoint interpolate(GeoPoint start, GeoPoint end, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final latitude = start.latitude + (end.latitude - start.latitude) * clamped;
    final longitude =
        start.longitude + (end.longitude - start.longitude) * clamped;
    return GeoPoint(latitude, longitude);
  }

  static GeoPoint _resolveOrigin(
    DeliveryMethod deliveryMethod,
    String normalizedCity,
    GeoPoint baseCity,
  ) {
    if (normalizedCity.contains('almaty') ||
        normalizedCity.contains('алматы')) {
      return deliveryMethod == DeliveryMethod.pickup
          ? _almatyPickupHub
          : _almatyAtelier;
    }

    final latitudeOffset = deliveryMethod == DeliveryMethod.pickup
        ? -0.008
        : -0.004;
    final longitudeOffset = deliveryMethod == DeliveryMethod.pickup
        ? 0.01
        : 0.015;
    return GeoPoint(
      baseCity.latitude + latitudeOffset,
      baseCity.longitude + longitudeOffset,
    );
  }

  static GeoPoint _resolveDestination({
    required DeliveryMethod deliveryMethod,
    required String normalizedCity,
    required String address,
    required String apartment,
    required GeoPoint baseCity,
  }) {
    final normalizedAddress = _normalize(address);
    final normalizedApartment = _normalize(apartment);

    if (deliveryMethod == DeliveryMethod.pickup) {
      if (normalizedAddress.contains('esentai') ||
          normalizedAddress.contains('esentai mall')) {
        return const GeoPoint(43.2185, 76.9277);
      }
      if (normalizedAddress.contains('mega') ||
          normalizedAddress.contains('rozybakieva') ||
          normalizedAddress.contains('247a') ||
          normalizedAddress.contains('247а')) {
        return const GeoPoint(43.201669, 76.892785);
      }
      return _offsetFromSeed(
        baseCity,
        seed: '$normalizedCity|pickup|$normalizedAddress|$normalizedApartment',
        latitudeRange: 0.014,
        longitudeRange: 0.02,
      );
    }

    if (normalizedAddress.contains('dostyk') ||
        normalizedAddress.contains('достык')) {
      return const GeoPoint(43.239637, 76.957191);
    }
    if (normalizedAddress.contains('abylai') ||
        normalizedAddress.contains('абылай')) {
      return const GeoPoint(43.262237, 76.941017);
    }
    if (normalizedAddress.contains('esentai')) {
      return const GeoPoint(43.2185, 76.9277);
    }
    if (normalizedAddress.contains('mega') ||
        normalizedAddress.contains('rozybakieva') ||
        normalizedAddress.contains('247a') ||
        normalizedAddress.contains('247а')) {
      return const GeoPoint(43.201669, 76.892785);
    }

    return _offsetFromSeed(
      baseCity,
      seed: '$normalizedCity|delivery|$normalizedAddress|$normalizedApartment',
      latitudeRange: 0.03,
      longitudeRange: 0.04,
    );
  }

  static GeoPoint _resolveCityCenter(String normalizedCity) {
    for (final entry in _cityCenters.entries) {
      if (normalizedCity.contains(entry.key)) {
        return entry.value;
      }
    }
    return _fallbackCityCenter;
  }

  static GeoPoint _offsetFromSeed(
    GeoPoint base, {
    required String seed,
    required double latitudeRange,
    required double longitudeRange,
  }) {
    final latSeed = _hashToUnit('$seed|lat');
    final lngSeed = _hashToUnit('$seed|lng');
    final latitude = base.latitude + ((latSeed - 0.5) * latitudeRange);
    final longitude = base.longitude + ((lngSeed - 0.5) * longitudeRange);
    return GeoPoint(latitude, longitude);
  }

  static double _hashToUnit(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return (hash.abs() % 10000) / 10000;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
