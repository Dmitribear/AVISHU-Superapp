import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/orders/domain/services/order_geocoding_service.dart';
import 'package:avishu/features/orders/domain/services/order_map_location_resolver.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveRoute uses geocoded destination when lookup succeeds', () async {
    late String requestedAddress;
    final service = OrderGeocodingService(
      lookup: (address) async {
        requestedAddress = address;
        return <Location>[
          Location(
            latitude: 43.255,
            longitude: 76.945,
            timestamp: DateTime.utc(2026, 3, 28),
          ),
        ];
      },
    );

    final route = await service.resolveRoute(
      deliveryMethod: DeliveryMethod.courier,
      city: 'Almaty',
      address: 'Dostyk 25',
      apartment: '12',
    );

    expect(requestedAddress, 'Kazakhstan, Almaty, Dostyk 25');
    expect(route.originLocation.latitude, closeTo(43.2331, 0.0001));
    expect(route.destinationLocation.latitude, 43.255);
    expect(route.destinationLocation.longitude, 76.945);
  });

  test('resolveRoute retries with address-first query when needed', () async {
    final requestedQueries = <String>[];
    final service = OrderGeocodingService(
      lookup: (address) async {
        requestedQueries.add(address);
        if (requestedQueries.length == 1) {
          return const <Location>[];
        }

        return <Location>[
          Location(
            latitude: 43.247,
            longitude: 76.901,
            timestamp: DateTime.utc(2026, 3, 28),
          ),
        ];
      },
    );

    final route = await service.resolveRoute(
      deliveryMethod: DeliveryMethod.courier,
      city: 'Almaty',
      address: 'Satpayev 22',
    );

    expect(
      requestedQueries,
      containsAllInOrder(<String>[
        'Kazakhstan, Almaty, Satpayev 22',
        'Satpayev 22, Almaty, Kazakhstan',
      ]),
    );
    expect(route.destinationLocation.latitude, 43.247);
    expect(route.destinationLocation.longitude, 76.901);
  });

  test(
    'resolveRoute falls back to internal resolver when lookup fails',
    () async {
      final service = OrderGeocodingService(
        lookup: (_) async => throw Exception('geocoder unavailable'),
      );

      final route = await service.resolveRoute(
        deliveryMethod: DeliveryMethod.courier,
        city: 'Almaty',
        address: 'Unknown Street 17',
      );
      final fallback = OrderMapLocationResolver.resolveRoute(
        deliveryMethod: DeliveryMethod.courier,
        city: 'Almaty',
        address: 'Unknown Street 17',
      );

      expect(route.originLocation, fallback.originLocation);
      expect(route.destinationLocation, fallback.destinationLocation);
    },
  );
}
