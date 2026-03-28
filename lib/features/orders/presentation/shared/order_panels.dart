import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../domain/enums/delivery_method.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/order_timeline_entry.dart';
import 'order_formatters.dart';

class OrderInfoCard extends StatelessWidget {
  final String title;
  final List<OrderInfoRowData> rows;

  const OrderInfoCard({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
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
          ...rows.indexed.map((entry) {
            final index = entry.$1;
            final row = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == rows.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class OrderInfoRowData {
  final String label;
  final String value;

  const OrderInfoRowData({required this.label, required this.value});
}

class OrderTimelineCard extends ConsumerWidget {
  final List<OrderTimelineEntry> timeline;

  const OrderTimelineCard({super.key, required this.timeline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appSettingsProvider).language;

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
          Text(
            tr(language, ru: 'ИСТОРИЯ СТАТУСОВ', en: 'STATUS HISTORY', kk: 'СТАТУСТАР ТАРИХЫ'),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 12),
          ...timeline.reversed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimelineRow(entry: entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final OrderTimelineEntry entry;

  const _TimelineRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: AppColors.black,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                entry.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.actor} / ${formatTimelineDate(entry.createdAt)}',
                style: AppTypography.code,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OrderSummaryRows {
  static List<OrderInfoRowData> forOrder(
    OrderModel order, {
    AppLanguage language = AppLanguage.russian,
  }) {
    return [
      OrderInfoRowData(
        label: tr(language, ru: 'Изделие', en: 'Product', kk: 'Бұйым'),
        value: order.productName,
      ),
      OrderInfoRowData(
        label: tr(language, ru: 'Размер', en: 'Size', kk: 'Өлшем'),
        value: order.sizeLabel,
      ),
      OrderInfoRowData(
        label: tr(language, ru: 'Сумма', en: 'Amount', kk: 'Сома'),
        value: formatCurrency(order.amount),
      ),
      OrderInfoRowData(
        label: tr(language, ru: 'Доставка', en: 'Delivery', kk: 'Жеткізу'),
        value: order.deliveryMethod.labelFor(language),
      ),
      OrderInfoRowData(
        label: tr(language, ru: 'Адрес', en: 'Address', kk: 'Мекенжай'),
        value: order.formattedAddress,
      ),
      OrderInfoRowData(
        label: tr(language, ru: 'Оплата', en: 'Payment', kk: 'Төлем'),
        value: order.paymentLast4.isEmpty
            ? tr(language, ru: 'Карта', en: 'Card', kk: 'Карта')
            : tr(
                language,
                ru: 'Карта *${order.paymentLast4}',
                en: 'Card *${order.paymentLast4}',
                kk: 'Карта *${order.paymentLast4}',
              ),
      ),
    ];
  }
}
