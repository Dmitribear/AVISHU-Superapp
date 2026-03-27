import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/global_state.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/orders/presentation/client/client_dashboard.dart';
import '../../features/orders/presentation/franchisee/franchisee_dashboard.dart';
import '../../features/orders/presentation/production/production_dashboard.dart';

class LoginScreen extends StatelessWidget { const LoginScreen({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('LOGIN - B&W BRUTALISM'))); }
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
