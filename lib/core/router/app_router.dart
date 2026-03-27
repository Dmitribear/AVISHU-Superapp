import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/orders/presentation/client/client_dashboard.dart';
import '../../features/orders/presentation/franchisee/franchisee_dashboard.dart';
import '../../features/orders/presentation/production/production_dashboard.dart';
import '../../shared/providers/global_state.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void enterRole(UserRole role) {
      ref.read(demoRoleProvider.notifier).state = role;
      context.go('/');
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const SizedBox(height: 52),
                              Text(
                                'AVISHU',
                                style: AppTypography.brandMark.copyWith(
                                  fontSize: 28,
                                  letterSpacing: 8,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'ВЫБЕРИТЕ РОЛЬ ДЛЯ АВТОРИЗАЦИИ',
                                textAlign: TextAlign.center,
                                style: AppTypography.eyebrow.copyWith(
                                  color: AppColors.outline,
                                ),
                              ),
                              const SizedBox(height: 26),
                              _RoleButton(
                                label: 'КЛИЕНТ',
                                onTap: () => enterRole(UserRole.client),
                              ),
                              const SizedBox(height: 12),
                              _RoleButton(
                                label: 'ФРАНЧАЙЗИ',
                                onTap: () => enterRole(UserRole.franchisee),
                              ),
                              const SizedBox(height: 12),
                              _RoleButton(
                                label: 'ПРОИЗВОДСТВО',
                                onTap: () => enterRole(UserRole.production),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.outlineVariant),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'V.2.04 / SECURE_ACCESS',
                                style: AppTypography.eyebrow,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: _CornerDecoration(top: true, left: true),
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: _CornerDecoration(top: true, left: false),
                  ),
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    child: _CornerDecoration(top: false, left: true),
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: _CornerDecoration(top: false, left: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: AppColors.black),
          alignment: Alignment.center,
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.button.copyWith(letterSpacing: 3.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerDecoration extends StatelessWidget {
  final bool top;
  final bool left;

  const _CornerDecoration({
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _CornerPainter(top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;

  const _CornerPainter({
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (top && left) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, 0)
        ..lineTo(0, size.height);
    } else if (top && !left) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (!top && left) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
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
      GoRoute(
        path: '/franchisee',
        builder: (context, state) => const FranchiseeDashboard(),
      ),
      GoRoute(
        path: '/production',
        builder: (context, state) => const ProductionDashboard(),
      ),
    ],
  );
});
