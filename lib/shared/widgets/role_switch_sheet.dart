import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/auth/domain/user_role.dart';
import '../providers/global_state.dart';

Future<void> showRoleSwitchSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROLE SWITCH', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              Text(
                'Выберите роль для демонстрации сквозного сценария.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _RoleSwitchTile(
                label: 'КЛИЕНТ',
                role: UserRole.client,
                route: '/client',
              ),
              const SizedBox(height: 10),
              _RoleSwitchTile(
                label: 'ФРАНЧАЙЗИ',
                role: UserRole.franchisee,
                route: '/franchisee',
              ),
              const SizedBox(height: 10),
              _RoleSwitchTile(
                label: 'ПРОИЗВОДСТВО',
                role: UserRole.production,
                route: '/production',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RoleSwitchTile extends ConsumerWidget {
  final String label;
  final UserRole role;
  final String route;

  const _RoleSwitchTile({
    required this.label,
    required this.role,
    required this.route,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          ref.read(demoRoleProvider.notifier).state = role;
          Navigator.of(context).pop();
          context.go(route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.button.copyWith(letterSpacing: 3),
                ),
              ),
              Text('OPEN', style: AppTypography.eyebrow),
            ],
          ),
        ),
      ),
    );
  }
}
