import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../domain/models/order_model.dart';
import 'order_digital_twin_helpers.dart';
import 'order_formatters.dart';

class OrderDigitalTwinCard extends ConsumerWidget {
  final OrderModel order;
  final String? clientDisplayName;
  final String? responsibleDisplayName;

  const OrderDigitalTwinCard({
    super.key,
    required this.order,
    this.clientDisplayName,
    this.responsibleDisplayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appSettingsProvider).language;
    final timeline = mapOrderHistoryToTimeline(order, language: language);
    final clientLabel = getClientDisplayLabel(
      order,
      clientName: clientDisplayName,
      language: language,
    );

    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 30), (tick) => tick),
      initialData: 0,
      builder: (context, _) {
        final currentStageDuration = getOrderCurrentStageDuration(
          order,
          language: language,
        );
        final responsibleLabel = getResponsibleLabel(
          order,
          responsibleName: responsibleDisplayName,
          language: language,
        );
        final statusLabel = formatOrderStatus(order.status, language: language);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            border: Border.all(color: AppColors.black),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'DIGITAL TWIN',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Text(statusLabel, style: AppTypography.button),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _labelValue(
                      context,
                      label: tr(
                        language,
                        ru: 'НОМЕР ЗАКАЗА',
                        en: 'ORDER NUMBER',
                        kk: 'ТАПСЫРЫС НӨМІРІ',
                      ),
                      value: order.orderNumber.isEmpty
                          ? 'AV-${order.shortId}'
                          : order.orderNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 104,
                    child: _labelValue(
                      context,
                      label: tr(
                        language,
                        ru: 'ПРИОРИТЕТ',
                        en: 'PRIORITY',
                        kk: 'БАСЫМДЫҚ',
                      ),
                      value: formatOrderPriority(
                        order.priority,
                        language: language,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                order.productName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _labelValue(
                context,
                label: tr(language, ru: 'КЛИЕНТ', en: 'CLIENT', kk: 'КЛИЕНТ'),
                value: clientLabel,
              ),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant,
              ),
              const SizedBox(height: 14),
              Text(
                tr(
                  language,
                  ru: 'ЖИВОЙ СТАТУС',
                  en: 'LIVE STATUS',
                  kk: 'ТІРІ КҮЙ',
                ),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: tr(
                            language,
                            ru: 'СТАТУС',
                            en: 'STATUS',
                            kk: 'КҮЙ',
                          ),
                          value: statusLabel,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: tr(
                            language,
                            ru: 'ВРЕМЯ НА ЭТАПЕ',
                            en: 'CURRENT STAGE',
                            kk: 'ОСЫ КЕЗЕҢ',
                          ),
                          value: '$currentStageDuration / $statusLabel',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: tr(
                            language,
                            ru: 'ОТВЕЧАЕТ',
                            en: 'RESPONSIBLE',
                            kk: 'ЖАУАПТЫ',
                          ),
                          value: responsibleLabel,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: 'ETA',
                          value: formatOrderEta(
                            order.estimatedReadyAt,
                            language: language,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant,
              ),
              const SizedBox(height: 14),
              Text(
                tr(language, ru: 'ТАЙМЛАЙН', en: 'TIMELINE', kk: 'КЕЗЕҢДЕР'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 14),
              ...timeline.indexed.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.$1 == timeline.length - 1 ? 0 : 14,
                  ),
                  child: _timelineRow(
                    context,
                    step: entry.$2,
                    isLast: entry.$1 == timeline.length - 1,
                    language: language,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant,
              ),
              const SizedBox(height: 14),
              Text(
                tr(language, ru: 'ДАННЫЕ', en: 'META', kk: 'МӘЛІМЕТ'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              _metaRow(
                context,
                label: tr(
                  language,
                  ru: 'ТИП ИСПОЛНЕНИЯ',
                  en: 'FULFILLMENT',
                  kk: 'ОРЫНДАЛУ ТҮРІ',
                ),
                value: formatFulfillmentTypeLabel(
                  order.fulfillmentType,
                  language: language,
                ),
              ),
              _metaRow(
                context,
                label: tr(
                  language,
                  ru: 'СУММА',
                  en: 'TOTAL AMOUNT',
                  kk: 'ЖИЫНТЫҚ СОММА',
                ),
                value: formatCurrency(order.totalAmount),
              ),
              _metaRow(
                context,
                label: tr(
                  language,
                  ru: 'СОЗДАН',
                  en: 'CREATED AT',
                  kk: 'ҚҰРЫЛҒАН',
                ),
                value: formatOrderMetaDate(order.createdAt, language: language),
              ),
              _metaRow(
                context,
                label: tr(
                  language,
                  ru: 'ПОСЛЕДНЕЕ ОБНОВЛЕНИЕ',
                  en: 'LAST STATUS CHANGE',
                  kk: 'СОҢҒЫ ЖАҢАРТУ',
                ),
                value: formatOrderMetaDate(
                  order.lastStatusChangedAt,
                  language: language,
                ),
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _labelValue(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.eyebrow),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _metricCell(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _timelineRow(
    BuildContext context, {
    required OrderTwinTimelineStep step,
    required bool isLast,
    required AppLanguage language,
  }) {
    final lineColor = step.isReached || step.isCurrent
        ? AppColors.black
        : AppColors.outlineVariant;
    final dotColor = step.isCurrent || step.isReached
        ? AppColors.black
        : AppColors.surfaceLowest;
    final textColor = step.isCurrent || step.isReached
        ? AppColors.black
        : AppColors.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: step.isCurrent ? 12 : 10,
                height: step.isCurrent ? 12 : 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  border: Border.all(color: AppColors.black),
                ),
              ),
              if (!isLast) Container(width: 1, height: 38, color: lineColor),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                step.timestamp == null
                    ? tr(language, ru: 'Ожидание', en: 'Pending', kk: 'Күту')
                    : formatOrderMetaDate(step.timestamp!, language: language),
                style: AppTypography.code.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
