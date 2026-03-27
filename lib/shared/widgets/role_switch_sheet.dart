import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/user_role.dart';
import '../providers/global_state.dart';

const _switchableRoles = <UserRole>[
  UserRole.client,
  UserRole.franchisee,
  UserRole.production,
];

String roleLabel(UserRole role) {
  if (role == UserRole.client) {
    return 'КЛИЕНТ';
  }
  if (role == UserRole.franchisee) {
    return 'ФРАНЧАЙЗИ';
  }
  if (role == UserRole.production) {
    return 'ПРОИЗВОДСТВО';
  }
  return 'ADMIN';
}

String roleRoute(UserRole role) {
  if (role == UserRole.client) {
    return '/client';
  }
  if (role == UserRole.franchisee) {
    return '/franchisee';
  }
  if (role == UserRole.production) {
    return '/production';
  }
  return '/franchisee';
}

String roleCaption(UserRole role) {
  if (role == UserRole.client) {
    return 'Catalog, checkout, and live order tracking.';
  }
  if (role == UserRole.franchisee) {
    return 'Incoming orders, acceptance, and transfer to production.';
  }
  if (role == UserRole.production) {
    return 'Factory queue, tailoring progress, and completion.';
  }
  return 'Demo control role.';
}

Future<void> showRoleSwitchSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      final currentRole = ref.read(currentUserProvider).value?.role;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('СМЕНА РОЛИ', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              if (currentRole != null) ...[
                Text(
                  'Текущая роль: ${roleLabel(currentRole)}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Выберите раздел приложения.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              ..._switchableRoles.map((role) {
                final isActive = role == currentRole;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoleSwitchTile(
                    label: roleLabel(role),
                    caption: roleCaption(role),
                    route: roleRoute(role),
                    isActive: isActive,
                  ),
                );
              }),
              const SizedBox(height: 10),
              const Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 10),
              _SignOutButton(),
            ],
          ),
        ),
      );
    },
  );
}

class RoleControlCard extends ConsumerWidget {
  final UserRole currentRole;
  final String title;

  const RoleControlCard({
    super.key,
    required this.currentRole,
    this.title = 'ROLE ACCESS',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.eyebrow),
          const SizedBox(height: 12),
          Text(
            'CURRENT ROLE',
            style: AppTypography.eyebrow.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 6),
          Text(
            roleLabel(currentRole),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            roleCaption(currentRole),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ..._switchableRoles.map((role) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InlineRoleButton(
                role: role,
                isActive: role == currentRole,
              ),
            );
          }),
          const SizedBox(height: 10),
          const Divider(color: AppColors.outlineVariant),
          const SizedBox(height: 10),
          _SignOutButton(),
        ],
      ),
    );
  }
}

class _RoleSwitchTile extends StatelessWidget {
  final String label;
  final String caption;
  final String route;
  final bool isActive;

  const _RoleSwitchTile({
    required this.label,
    required this.caption,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pop();
          context.go(route);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? AppColors.black : AppColors.surfaceLowest,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.button.copyWith(
                        letterSpacing: 3,
                        color: isActive ? AppColors.white : AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? AppColors.surfaceHighest
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isActive ? 'CURRENT' : 'OPEN',
                style: AppTypography.eyebrow.copyWith(
                  color: isActive ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineRoleButton extends StatelessWidget {
  final UserRole role;
  final bool isActive;

  const _InlineRoleButton({required this.role, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isActive ? null : () => context.go(roleRoute(role)),
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? AppColors.black : AppColors.surfaceLowest,
          disabledBackgroundColor: AppColors.black,
          disabledForegroundColor: AppColors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  roleLabel(role),
                  style: AppTypography.button.copyWith(
                    letterSpacing: 3,
                    color: isActive ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
              Text(
                isActive ? 'CURRENT' : 'GO',
                style: AppTypography.eyebrow.copyWith(
                  color: isActive ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) {
            context.go('/login');
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
        ),
        child: Text(
          'SIGN OUT',
          style: AppTypography.button.copyWith(
            color: AppColors.error,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
