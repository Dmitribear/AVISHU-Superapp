import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/franchise_value/presentation/why_avishu_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/orders/presentation/client/client_dashboard.dart';
import '../../features/orders/presentation/franchisee/franchisee_dashboard.dart';
import '../../features/orders/presentation/production/production_dashboard.dart';
import '../../shared/providers/global_state.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.black)),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) {
        return '/loading';
      }

      final user = authState.value;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute || loc == '/' || loc == '/loading') {
        switch (user.role) {
          case UserRole.client:
            return '/client';
          case UserRole.franchisee:
            return '/franchisee';
          case UserRole.production:
            return '/production';
          case UserRole.admin:
            return '/franchisee';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoadingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => const ClientDashboard(),
      ),
      GoRoute(
        path: '/franchisee',
        builder: (context, state) => const FranchiseeDashboard(),
      ),
      GoRoute(
        path: '/production',
        builder: (context, state) => const ProductionDashboard(),
      ),
      GoRoute(
        path: '/why-avishu',
        builder: (context, state) => const WhyAvishuScreen(),
      ),
    ],
  );
});
