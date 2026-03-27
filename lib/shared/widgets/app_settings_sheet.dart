import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/auth/data/auth_repository.dart';
import '../i18n/app_localization.dart';
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
    final language = settings.language;

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
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: tr(language, ru: 'Закрыть', en: 'Close'),
                    icon: const Icon(Icons.close, color: AppColors.black),
                  ),
                ),
                Text(
                  tr(language, ru: 'НАСТРОЙКИ', en: 'SETTINGS'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    language,
                    ru: 'Параметры интерфейса и уведомлений для демо-сценария.',
                    en: 'Interface and notification controls for the demo scenario.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _SwitchTile(
                  title: tr(language, ru: 'Уведомления', en: 'Notifications'),
                  subtitle: tr(
                    language,
                    ru: 'Показывать обновления по заказам.',
                    en: 'Show order update notifications.',
                  ),
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotifications,
                ),
                const SizedBox(height: 10),
                _SwitchTile(
                  title: tr(language, ru: 'Звук в цехе', en: 'Factory Sound'),
                  subtitle: tr(
                    language,
                    ru: 'Сигнал для новых задач производства.',
                    en: 'Sound cue for new production tasks.',
                  ),
                  value: settings.productionSoundEnabled,
                  onChanged: controller.setProductionSound,
                ),
                const SizedBox(height: 10),
                _SwitchTile(
                  title: tr(
                    language,
                    ru: 'Компактные карточки',
                    en: 'Compact Cards',
                  ),
                  subtitle: tr(
                    language,
                    ru: 'Уменьшить вертикальные отступы в списках.',
                    en: 'Reduce vertical spacing in operational lists.',
                  ),
                  value: settings.compactCards,
                  onChanged: controller.setCompactCards,
                ),
                const SizedBox(height: 10),
                _SelectionTile<AppLanguage>(
                  title: tr(
                    language,
                    ru: 'Язык интерфейса',
                    en: 'Interface Language',
                  ),
                  subtitle: tr(
                    language,
                    ru: 'Переводит системные подписи интерфейса.',
                    en: 'Translates system interface labels.',
                  ),
                  options: AppLanguage.values
                      .map(
                        (value) => _SelectionOption<AppLanguage>(
                          value: value,
                          label: appLanguageLabel(value),
                        ),
                      )
                      .toList(),
                  selectedValue: settings.language,
                  onSelected: controller.setLanguage,
                ),
                const SizedBox(height: 10),
                _SelectionTile<CatalogCardSize>(
                  title: tr(
                    language,
                    ru: 'Размер карточек каталога',
                    en: 'Catalog Card Size',
                  ),
                  subtitle: tr(
                    language,
                    ru: 'Масштаб карточек одежды в каталоге и избранном.',
                    en: 'Controls clothing card size in catalog and favorites.',
                  ),
                  options: CatalogCardSize.values
                      .map(
                        (value) => _SelectionOption<CatalogCardSize>(
                          value: value,
                          label: catalogCardSizeLabel(value),
                        ),
                      )
                      .toList(),
                  selectedValue: settings.catalogCardSize,
                  onSelected: controller.setCatalogCardSize,
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
                        tr(
                          language,
                          ru: 'Сервисная информация',
                          en: 'Service Info',
                        ),
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          language,
                          ru: 'AVISHU v2.04\nКлиент, франчайзи, производство',
                          en: 'AVISHU v2.04\nClient, franchisee, factory',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      tr(language, ru: 'ЗАКРЫТЬ', en: 'CLOSE'),
                      style: AppTypography.button.copyWith(letterSpacing: 3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                      tr(language, ru: 'ВЫЙТИ ИЗ АККАУНТА', en: 'SIGN OUT'),
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

class _SelectionOption<T> {
  final T value;
  final String label;

  const _SelectionOption({required this.value, required this.label});
}

class _SelectionTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_SelectionOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
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
          const SizedBox(height: 12),
          Row(
            children: options
                .map(
                  (option) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: option == options.last ? 0 : 8,
                      ),
                      child: InkWell(
                        onTap: () => onSelected(option.value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: option.value == selectedValue
                                ? AppColors.black
                                : AppColors.surfaceLowest,
                            border: Border.all(color: AppColors.black),
                          ),
                          child: Text(
                            option.label,
                            textAlign: TextAlign.center,
                            style: AppTypography.button.copyWith(
                              color: option.value == selectedValue
                                  ? AppColors.white
                                  : AppColors.black,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
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
