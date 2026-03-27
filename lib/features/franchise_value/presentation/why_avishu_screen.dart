import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/i18n/app_localization.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/widgets/avishu_mobile_frame.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/enums/order_status.dart';
import '../../orders/domain/models/order_model.dart';
import '../../orders/presentation/shared/order_formatters.dart';
import 'why_avishu_content.dart';
import 'why_avishu_metrics.dart';

final whyAvishuOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).allOrders();
});

class WhyAvishuScreen extends ConsumerWidget {
  const WhyAvishuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(whyAvishuOrdersProvider);
    final language = ref.watch(appSettingsProvider).language;

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: tr(
        language,
        ru: 'РЕЖИМ ЦЕННОСТИ ФРАНШИЗЫ',
        en: 'FRANCHISE VALUE MODE',
      ),
      leadingIcon: Icons.arrow_back,
      onLeadingTap: () => context.pop(),
      actionIcon: null,
      showBottomNav: false,
      navItems: const <AvishuNavItem>[],
      currentIndex: 0,
      onNavSelected: (_) {},
      body: ordersAsync.when(
        data: (orders) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: _WhyAvishuBody(
            orders: orders,
            metrics: deriveWhyAvishuMetrics(orders),
            language: language,
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (error, _) => Center(
          child: Text(
            tr(
              language,
              ru: 'Не удалось загрузить данные: $error',
              en: 'Failed to load: $error',
            ),
          ),
        ),
      ),
    );
  }
}

class _WhyAvishuBody extends StatelessWidget {
  final List<OrderModel> orders;
  final WhyAvishuMetrics metrics;
  final AppLanguage language;

  const _WhyAvishuBody({
    required this.orders,
    required this.metrics,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final copy = whyAvishuContentFor(language);
    final activeRevenue = orders
        .where(
          (order) =>
              order.status != OrderStatus.completed &&
              order.status != OrderStatus.cancelled,
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(context, copy),
        const SizedBox(height: 16),
        _valueGrid(context, copy),
        const SizedBox(height: 16),
        _liveSummary(context, activeRevenue),
        const SizedBox(height: 16),
        _flowBlock(context, copy),
        const SizedBox(height: 16),
        _closingBlock(context, copy),
      ],
    );
  }

  Widget _hero(BuildContext context, WhyAvishuContent copy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              language,
              ru: 'ВНУТРЕННИЙ ПРОДУКТОВЫЙ РЕЖИМ',
              en: 'EXECUTIVE PRODUCT VIEW',
            ),
            style: AppTypography.eyebrow.copyWith(color: AppColors.surfaceDim),
          ),
          const SizedBox(height: 18),
          Text(
            copy.heroTitle,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Text(
            copy.heroStatement,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.outline),
          const SizedBox(height: 14),
          Text(
            copy.heroSummary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.surfaceHighest),
          ),
        ],
      ),
    );
  }

  Widget _valueGrid(BuildContext context, WhyAvishuContent copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(language, ru: 'БЛОКИ ЦЕННОСТИ', en: 'VALUE BLOCKS'),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: 12),
        ...copy.valueBlocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _valueCard(context, block),
          ),
        ),
      ],
    );
  }

  Widget _valueCard(BuildContext context, WhyAvishuValueBlock block) {
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
          Text(block.title, style: AppTypography.button),
          const SizedBox(height: 10),
          Text(
            block.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _liveSummary(BuildContext context, double activeRevenue) {
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
          Text(
            tr(
              language,
              ru: 'ЖИВАЯ СВОДКА БИЗНЕСА',
              en: 'LIVE BUSINESS SUMMARY',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(
                        language,
                        ru: 'ЗАКАЗЫ СЕГОДНЯ',
                        en: "TODAY'S ORDERS",
                      ),
                      value: metrics.todayOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(
                        language,
                        ru: 'АКТИВНЫЙ ПОТОК',
                        en: 'ACTIVE FLOW',
                      ),
                      value: metrics.activeOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(
                        language,
                        ru: 'В ПРОИЗВОДСТВЕ',
                        en: 'IN PRODUCTION',
                      ),
                      value: metrics.inProductionOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(language, ru: 'ГОТОВО', en: 'READY'),
                      value: metrics.readyOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(
                        language,
                        ru: 'СРЕДНЕЕ ВРЕМЯ ДО ГОТОВНОСТИ',
                        en: 'AVG TIME TO READY',
                      ),
                      value: metrics.averageTimeToReady,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: tr(
                        language,
                        ru: 'АКТИВНАЯ ВЫРУЧКА',
                        en: 'ACTIVE VALUE',
                      ),
                      value: formatCurrency(activeRevenue),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricBox(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 14),
          Text(value, style: AppTypography.metricValue),
        ],
      ),
    );
  }

  Widget _flowBlock(BuildContext context, WhyAvishuContent copy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(language, ru: 'СИСТЕМНЫЙ ПОТОК', en: 'SYSTEM FLOW'),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 14),
          ...copy.flowLabels.indexed.map(
            (entry) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: entry.$1 == copy.flowLabels.length - 1
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    entry.$2,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (entry.$1 != copy.flowLabels.length - 1)
                    Text('→', style: AppTypography.button),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closingBlock(BuildContext context, WhyAvishuContent copy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(language, ru: 'ПОЗИЦИОНИРОВАНИЕ', en: 'POSITIONING'),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 18),
          Text(
            copy.closingTitle,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            copy.closingStatement,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
