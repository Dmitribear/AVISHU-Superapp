import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('login screen shows auth fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('AVISHU'), findsOneWidget);
    expect(find.text('АВТОРИЗАЦИЯ'), findsOneWidget);
    expect(find.text('ВОЙТИ'), findsOneWidget);
    expect(find.text('РЕГИСТРАЦИЯ'), findsOneWidget);
  });
}
