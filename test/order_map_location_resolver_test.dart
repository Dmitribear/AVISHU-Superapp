import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/services/order_map_location_resolver.dart';

void main() {
  test('resolver keeps known Almaty addresses stable', () {
    final route = OrderMapLocationResolver.resolveRoute(
      deliveryMethod: DeliveryMethod.courier,
      city: 'Almaty',
      address: 'Dostyk Ave 25',
      apartment: '12',
    );

    expect(route.originLocation, const GeoPoint(43.2331, 76.9569));
    expect(route.destinationLocation, const GeoPoint(43.239637, 76.957191));
  });

  test('resolver interpolation moves courier along the route', () {
    const origin = GeoPoint(43.2331, 76.9569);
    const destination = GeoPoint(43.239637, 76.957191);

    final midpoint = OrderMapLocationResolver.interpolate(
      origin,
      destination,
      0.5,
    );

    expect(midpoint.latitude, closeTo(43.2363685, 0.000001));
    expect(midpoint.longitude, closeTo(76.9570455, 0.000001));
  });
}
