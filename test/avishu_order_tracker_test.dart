import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/domain/enums/order_status.dart';
import 'package:avishu/shared/widgets/avishu_order_tracker.dart';

Widget _wrap(OrderStatus status) {
  return MaterialApp(
    home: Scaffold(
      body: AvishuOrderTracker(status: status),
    ),
  );
}

void main() {
  group('AvishuOrderTracker', () {
    testWidgets('shows all three step titles for newOrder (stage 0)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrderStatus.newOrder));

      expect(find.text('ОФОРМЛЕН'), findsOneWidget);
      expect(find.text('ПОШИВ'), findsOneWidget);
      expect(find.text('ГОТОВ'), findsOneWidget);

      // No sub-text for stage 0.
      expect(find.text('МАСТЕР ПРИСТУПИЛ К РАБОТЕ'), findsNothing);
    });

    testWidgets('shows sub-text when status is inProduction (stage 1)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrderStatus.inProduction));

      expect(find.text('ПОШИВ'), findsOneWidget);
      expect(find.text('МАСТЕР ПРИСТУПИЛ К РАБОТЕ'), findsOneWidget);
    });

    testWidgets('shows all titles and no sub-text when status is ready (stage 2)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrderStatus.ready));

      expect(find.text('ОФОРМЛЕН'), findsOneWidget);
      expect(find.text('ПОШИВ'), findsOneWidget);
      expect(find.text('ГОТОВ'), findsOneWidget);
      expect(find.text('МАСТЕР ПРИСТУПИЛ К РАБОТЕ'), findsNothing);
    });

    test('triggerHapticIfChanged does not throw', () {
      // Verify the static helper runs without error.
      expect(
        () => AvishuOrderTracker.triggerHapticIfChanged(
          OrderStatus.newOrder,
          OrderStatus.inProduction,
        ),
        returnsNormally,
      );
    });
  });
}
