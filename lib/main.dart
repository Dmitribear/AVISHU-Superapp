import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'shared/demo/product_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ВРЕМЕННЫЙ ВЫЗОВ: Добавляет кастомный товар в БД при запуске.
    // Можно удалить после первого успешного запуска.
    await ProductSeeder.addSingleProduct();

    debugPrint(
      'AVISHU DEBUG: Firebase initialized successfully for '
      '${DefaultFirebaseOptions.currentPlatform.projectId}',
    );
  } catch (e) {
    debugPrint('AVISHU DEBUG: Firebase init error: $e');
  }
  runApp(const ProviderScope(child: AvishuApp()));
}

class AvishuApp extends ConsumerWidget {
  const AvishuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AVISHU',
      theme: AppTheme.brutalistTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
