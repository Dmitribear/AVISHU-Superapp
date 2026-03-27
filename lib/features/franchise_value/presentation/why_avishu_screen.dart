import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
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

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: 'FRANCHISE VALUE MODE',
      leadingIcon: Icons.arrow_back,
      onLeadingTap: () => context.pop(),
      actionIcon: Icons.grid_view_rounded,
      onActionTap: () => context.go('/franchisee'),
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
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
      ),
    );
  }
}

class _WhyAvishuBody extends StatelessWidget {
  final List<OrderModel> orders;
  final WhyAvishuMetrics metrics;

  const _WhyAvishuBody({required this.orders, required this.metrics});

  @override
  Widget build(BuildContext context) {
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
        _hero(context),
        const SizedBox(height: 16),
        _valueGrid(context),
        const SizedBox(height: 16),
        _liveSummary(context, activeRevenue),
        const SizedBox(height: 16),
        _flowBlock(context),
        const SizedBox(height: 16),
        _closingBlock(context),
      ],
    );
  }

  Widget _hero(BuildContext context) {
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
            'EXECUTIVE PRODUCT VIEW',
            style: AppTypography.eyebrow.copyWith(color: AppColors.surfaceDim),
          ),
          const SizedBox(height: 18),
          Text(
            whyAvishuHeroTitle,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Text(
            whyAvishuHeroStatement,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.outline),
          const SizedBox(height: 14),
          Text(
            whyAvishuHeroSummary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.surfaceHighest),
          ),
        ],
      ),
    );
  }

  Widget _valueGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VALUE BLOCKS', style: AppTypography.eyebrow),
        const SizedBox(height: 12),
        ...whyAvishuValueBlocks.map(
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
          Text('LIVE BUSINESS SUMMARY', style: AppTypography.eyebrow),
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
                      label: "TODAY'S ORDERS",
                      value: metrics.todayOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: 'ACTIVE FLOW',
                      value: metrics.activeOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: 'IN PRODUCTION',
                      value: metrics.inProductionOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: 'READY',
                      value: metrics.readyOrders.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: 'AVG TIME TO READY',
                      value: metrics.averageTimeToReady,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricBox(
                      context,
                      label: 'ACTIVE VALUE',
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

  Widget _flowBlock(BuildContext context) {
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
          Text('SYSTEM FLOW', style: AppTypography.eyebrow),
          const SizedBox(height: 14),
          ...whyAvishuFlowLabels.indexed.map(
            (entry) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: entry.$1 == whyAvishuFlowLabels.length - 1
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
                  if (entry.$1 != whyAvishuFlowLabels.length - 1)
                    Text('→', style: AppTypography.button),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closingBlock(BuildContext context) {
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
          Text('POSITIONING', style: AppTypography.eyebrow),
          const SizedBox(height: 18),
          Text(
            whyAvishuClosingTitle,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            whyAvishuClosingStatement,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
