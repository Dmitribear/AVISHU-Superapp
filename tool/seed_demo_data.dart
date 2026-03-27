import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:avishu/firebase_options.dart';
import 'package:avishu/shared/demo/demo_seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final result = await DemoSeedService().seedAll();
  runApp(_SeedResultApp(result: result));
}

class _SeedResultApp extends StatelessWidget {
  final DemoSeedResult result;

  const _SeedResultApp({required this.result});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Text(
                  'AVISHU demo seed completed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Credentials',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...result.users.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${user.role.value}: ${user.email} / ${user.password}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Products: ${result.productIds.join(', ')}'),
                const SizedBox(height: 8),
                Text('Orders: ${result.orderIds.join(', ')}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
