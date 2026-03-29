import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../shared/i18n/app_localization.dart';
import '../../../../../shared/providers/app_settings.dart';
import '../../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../orders/data/order_repository.dart';
import '../../../../orders/domain/models/order_model.dart';
import '../models/why_avishu_metrics.dart';
import 'why_avishu_body.dart';

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
          child: WhyAvishuBody(
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
