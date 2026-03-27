import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/auth/domain/user_role.dart';
import '../providers/global_state.dart';

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.client:
      return 'КЛИЕНТ';
    case UserRole.franchisee:
      return 'ФРАНЧАЙЗИ';
    case UserRole.production:
      return 'ПРОИЗВОДСТВО';
  }
}

String roleRoute(UserRole role) {
  switch (role) {
    case UserRole.client:
      return '/client';
    case UserRole.franchisee:
      return '/franchisee';
    case UserRole.production:
      return '/production';
  }
}

String roleCaption(UserRole role) {
  switch (role) {
    case UserRole.client:
      return 'Витрина, заказ, оплата и трекинг.';
    case UserRole.franchisee:
      return 'Подтверждение заказа и передача в цех.';
    case UserRole.production:
      return 'Очередь задач, пошив и завершение.';
  }
}

Future<void> showRoleSwitchSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      final currentRole = ref.watch(currentUserProvider).value?.role;

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
                'Выберите роль для демонстрации сквозного сценария.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              ...UserRole.values.map((role) {
                final isActive = role == currentRole;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoleSwitchTile(
                    label: roleLabel(role),
                    caption: roleCaption(role),
                    route: roleRoute(role),
                    role: role,
                    isActive: isActive,
                  ),
                );
              }),
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
    this.title = 'РОЛЬ И ДОСТУП',
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
            'ТЕКУЩАЯ РОЛЬ',
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
          ...UserRole.values.map((role) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InlineRoleButton(
                role: role,
                isActive: role == currentRole,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RoleSwitchTile extends ConsumerWidget {
  final String label;
  final String caption;
  final UserRole role;
  final String route;
  final bool isActive;

  const _RoleSwitchTile({
    required this.label,
    required this.caption,
    required this.role,
    required this.route,
    required this.isActive,
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
                        color: isActive ? AppColors.surfaceHighest : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isActive ? 'ACTIVE' : 'OPEN',
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

class _InlineRoleButton extends ConsumerWidget {
  final UserRole role;
  final bool isActive;

  const _InlineRoleButton({
    required this.role,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = roleLabel(role);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isActive
            ? null
            : () {
                ref.read(demoRoleProvider.notifier).state = role;
                context.go(roleRoute(role));
              },
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
                  label,
                  style: AppTypography.button.copyWith(
                    letterSpacing: 3,
                    color: isActive ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
              Text(
                isActive ? 'ТЕКУЩАЯ' : 'ПЕРЕЙТИ',
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
