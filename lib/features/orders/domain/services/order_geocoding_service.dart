import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../enums/delivery_method.dart';
import 'order_map_location_resolver.dart';

typedef OrderAddressLookup = Future<List<Location>> Function(String address);

final orderGeocodingServiceProvider = Provider<OrderGeocodingService>(
  (ref) => const OrderGeocodingService(),
);

class OrderGeocodingService {
  final OrderAddressLookup _lookup;

  const OrderGeocodingService({OrderAddressLookup? lookup})
    : _lookup = lookup ?? locationFromAddress;

  Future<OrderRouteLocations> resolveRoute({
    required DeliveryMethod deliveryMethod,
    required String city,
    required String address,
    String apartment = '',
  }) async {
    final fallback = OrderMapLocationResolver.resolveRoute(
      deliveryMethod: deliveryMethod,
      city: city,
      address: address,
      apartment: apartment,
    );

    if (city.trim().isEmpty || address.trim().isEmpty) {
      return fallback;
    }

    final geocodedDestination = await _resolveDestination(
      city: city,
      address: address,
    );
    if (geocodedDestination == null) {
      return fallback;
    }

    return OrderRouteLocations(
      originLocation: fallback.originLocation,
      destinationLocation: geocodedDestination,
    );
  }

  Future<GeoPoint?> _resolveDestination({
    required String city,
    required String address,
  }) async {
    for (final query in _queries(city: city, address: address)) {
      try {
        final locations = await _lookup(query);
        if (locations.isEmpty) {
          continue;
        }

        final location = locations.first;
        return GeoPoint(location.latitude, location.longitude);
      } catch (_) {}
    }

    return null;
  }

  List<String> _queries({required String city, required String address}) {
    final normalizedCity = city.trim();
    final normalizedAddress = address.trim();

    return <String>[
      'Kazakhstan, $normalizedCity, $normalizedAddress',
      '$normalizedAddress, $normalizedCity, Kazakhstan',
      '$normalizedCity, $normalizedAddress',
      '$normalizedAddress, $normalizedCity',
      normalizedAddress,
    ];
  }
}
