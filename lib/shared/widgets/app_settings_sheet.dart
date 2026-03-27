import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/auth/data/auth_repository.dart';
import '../providers/app_settings.dart';

Future<void> showAppSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final screenHeight = MediaQuery.sizeOf(sheetContext).height;

      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: screenHeight * 0.82,
          ),
          child: Material(
            color: AppColors.surfaceLowest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            clipBehavior: Clip.antiAlias,
            child: const _AppSettingsSheet(),
          ),
        ),
      );
    },
  );
}

class _AppSettingsSheet extends ConsumerWidget {
  const _AppSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('НАСТРОЙКИ', style: AppTypography.eyebrow),
                const SizedBox(height: 8),
                Text(
                  'Параметры интерфейса и уведомлений для демо-сценария.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _SwitchTile(
                  title: 'Уведомления',
                  subtitle: 'Показывать обновления по заказам.',
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotifications,
                ),
                const SizedBox(height: 10),
                _SwitchTile(
                  title: 'Звук в цехе',
                  subtitle: 'Сигнал для новых задач производства.',
                  value: settings.productionSoundEnabled,
                  onChanged: controller.setProductionSound,
                ),
                const SizedBox(height: 10),
                _SwitchTile(
                  title: 'Компактные карточки',
                  subtitle: 'Уменьшить вертикальные отступы в списках.',
                  value: settings.compactCards,
                  onChanged: controller.setCompactCards,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сервисная информация',
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AVISHU v2.04\nКлиент, франчайзи, производство',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) {
                        GoRouter.of(context).go('/login');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: Text(
                      'ВЫЙТИ ИЗ АККАУНТА',
                      style: AppTypography.button.copyWith(
                        color: AppColors.error,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.black,
          ),
        ],
      ),
    );
  }
}
