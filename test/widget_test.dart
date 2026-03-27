import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/core/router/app_router.dart';

void main() {
  testWidgets('login screen shows role choices', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('AVISHU'), findsOneWidget);
    expect(find.text('КЛИЕНТ'), findsOneWidget);
    expect(find.text('ФРАНЧАЙЗИ'), findsOneWidget);
    expect(find.text('ПРОИЗВОДСТВО'), findsOneWidget);
  });
}
