import 'package:flutter/material.dart';

import '../../../../../shared/i18n/app_localization.dart';
import '../../../../orders/domain/enums/order_status.dart';
import '../../../../orders/domain/models/order_model.dart';
import '../../../../orders/presentation/shared/order_formatters.dart';
import '../content/why_avishu_content.dart';
import '../models/why_avishu_metrics.dart';
import '../organisms/why_avishu_closing_section.dart';
import '../organisms/why_avishu_flow_section.dart';
import '../organisms/why_avishu_hero_section.dart';
import '../organisms/why_avishu_live_summary_section.dart';
import '../organisms/why_avishu_value_blocks_section.dart';

class WhyAvishuBody extends StatelessWidget {
  final List<OrderModel> orders;
  final WhyAvishuMetrics metrics;
  final AppLanguage language;

  const WhyAvishuBody({
    super.key,
    required this.orders,
    required this.metrics,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final content = whyAvishuContentFor(language);
    final activeRevenue = _activeRevenueFromOrders(orders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WhyAvishuHeroSection(language: language, content: content),
        const SizedBox(height: 16),
        WhyAvishuValueBlocksSection(
          language: language,
          blocks: content.valueBlocks,
        ),
        const SizedBox(height: 16),
        WhyAvishuLiveSummarySection(
          language: language,
          metrics: [
            WhyAvishuMetricTileData(
              label: tr(language, ru: 'ЗАКАЗЫ СЕГОДНЯ', en: "TODAY'S ORDERS"),
              value: metrics.todayOrders.toString(),
            ),
            WhyAvishuMetricTileData(
              label: tr(language, ru: 'АКТИВНЫЙ ПОТОК', en: 'ACTIVE FLOW'),
              value: metrics.activeOrders.toString(),
            ),
            WhyAvishuMetricTileData(
              label: tr(language, ru: 'В ПРОИЗВОДСТВЕ', en: 'IN PRODUCTION'),
              value: metrics.inProductionOrders.toString(),
            ),
            WhyAvishuMetricTileData(
              label: tr(language, ru: 'ГОТОВО', en: 'READY'),
              value: metrics.readyOrders.toString(),
            ),
            WhyAvishuMetricTileData(
              label: tr(
                language,
                ru: 'СРЕДНЕЕ ВРЕМЯ ДО ГОТОВНОСТИ',
                en: 'AVG TIME TO READY',
              ),
              value: metrics.averageTimeToReady,
            ),
            WhyAvishuMetricTileData(
              label: tr(language, ru: 'АКТИВНАЯ ВЫРУЧКА', en: 'ACTIVE VALUE'),
              value: formatCurrency(activeRevenue),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WhyAvishuFlowSection(
          language: language,
          flowLabels: content.flowLabels,
        ),
        const SizedBox(height: 16),
        WhyAvishuClosingSection(
          language: language,
          title: content.closingTitle,
          statement: content.closingStatement,
        ),
      ],
    );
  }
}

double _activeRevenueFromOrders(List<OrderModel> orders) {
  return orders
      .where(
        (order) =>
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled,
      )
      .fold<double>(0, (sum, order) => sum + order.totalAmount);
}
