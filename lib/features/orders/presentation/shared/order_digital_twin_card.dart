import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/models/order_model.dart';
import 'order_digital_twin_helpers.dart';
import 'order_formatters.dart';

class OrderDigitalTwinCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final timeline = mapOrderHistoryToTimeline(order);
    final clientLabel = getClientDisplayLabel(
      order,
      clientName: clientDisplayName,
    );

    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 30), (tick) => tick),
      initialData: 0,
      builder: (context, _) {
        final currentStageDuration = getOrderCurrentStageDuration(order);
        final responsibleLabel = getResponsibleLabel(
          order,
          responsibleName: responsibleDisplayName,
        );

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
                  Text(
                    formatOrderStatus(order.status),
                    style: AppTypography.button,
                  ),
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
                      label: 'ORDER NUMBER',
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
                      label: 'PRIORITY',
                      value: formatOrderPriority(order.priority),
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
              _labelValue(context, label: 'CLIENT', value: clientLabel),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant,
              ),
              const SizedBox(height: 14),
              Text('LIVE STATUS', style: AppTypography.eyebrow),
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
                          label: 'STATUS',
                          value: formatOrderStatus(order.status),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: 'CURRENT STAGE',
                          value:
                              '$currentStageDuration ${formatOrderStatus(order.status)}',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: 'RESPONSIBLE',
                          value: responsibleLabel,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCell(
                          context,
                          label: 'ETA',
                          value: formatOrderEta(order.estimatedReadyAt),
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
              Text('TIMELINE', style: AppTypography.eyebrow),
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
              Text('META', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              _metaRow(
                context,
                label: 'FULFILLMENT',
                value: formatFulfillmentTypeLabel(order.fulfillmentType),
              ),
              _metaRow(
                context,
                label: 'TOTAL AMOUNT',
                value: formatCurrency(order.totalAmount),
              ),
              _metaRow(
                context,
                label: 'CREATED AT',
                value: formatOrderMetaDate(order.createdAt),
              ),
              _metaRow(
                context,
                label: 'LAST STATUS CHANGE',
                value: formatOrderMetaDate(order.lastStatusChangedAt),
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
                    ? 'PENDING'
                    : formatOrderMetaDate(step.timestamp!),
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
