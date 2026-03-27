import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/global_state.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/orders/presentation/client/client_dashboard.dart';
import '../../features/orders/presentation/franchisee/franchisee_dashboard.dart';
import '../../features/orders/presentation/production/production_dashboard.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/avishu_button.dart';

class LoginScreen extends StatelessWidget { 
  const LoginScreen({super.key}); 
  
  @override 
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('AVISHU B&W BRUTALISM', style: TextStyle(letterSpacing: 4.0, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          AvishuButton(
            text: 'TEST FIREBASE', 
            onPressed: () async {
              print('AVISHU DEBUG: Test button pressed');
              try {
                print('AVISHU DEBUG: Attempting to write to Firestore...');
                final ref = FirebaseFirestore.instance.collection('health_check').doc();
                await ref.set({
                  'status': 'connected',
                  'timestamp': FieldValue.serverTimestamp(),
                  'platform': 'flutter',
                }).timeout(const Duration(seconds: 10));
                
                print('AVISHU DEBUG: Write successful!');
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('SUCCESS'),
                      content: const Text('Firebase is working! Document created in "health_check" collection.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  );
                }
              } catch (e, stack) {
                print('AVISHU DEBUG: ERROR: $e');
                print('AVISHU DEBUG: STACK: $stack');
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('FIREBASE ERROR'),
                      content: Text(e.toString()),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  );
                }
              }
            }
          ),
        ],
      ),
    ),
  ); 
}
class LoadingScreen extends StatelessWidget { const LoadingScreen({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black))); }

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return '/loading';

      final user = authState.value;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || state.matchedLocation == '/') {
        switch (user.role) {
          case UserRole.client:
            return '/client';
          case UserRole.franchisee:
            return '/franchisee';
          case UserRole.production:
            return '/production';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoadingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/loading', builder: (context, state) => const LoadingScreen()),
      GoRoute(path: '/client', builder: (context, state) => const ClientDashboard()),
      GoRoute(path: '/franchisee', builder: (context, state) => const FranchiseeDashboard()),
      GoRoute(path: '/production', builder: (context, state) => const ProductionDashboard()),
    ],
  );
});
