import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../features/auth/domain/user_role.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../shared/widgets/role_switch_sheet.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';

final productionAllOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).allOrders();
});

enum ProductionTab { dashboard, queue, ready, station }

class ProductionDashboard extends ConsumerStatefulWidget {
  const ProductionDashboard({super.key});

  @override
  ConsumerState<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends ConsumerState<ProductionDashboard> {
  ProductionTab _tab = ProductionTab.dashboard;
  OrderModel? _selectedOrder;

  static const _navItems = [
    AvishuNavItem(label: 'ОБЗОР', icon: Icons.dashboard_outlined),
    AvishuNavItem(label: 'ОЧЕРЕДЬ', icon: Icons.format_list_bulleted_rounded),
    AvishuNavItem(label: 'ГОТОВО', icon: Icons.checkroom_outlined),
    AvishuNavItem(label: 'СТАНЦИЯ', icon: Icons.precision_manufacturing_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(productionAllOrdersProvider);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null ? 'PRODUCTION / TABLET' : 'PRODUCTION / TASK',
      leadingIcon: _selectedOrder == null ? Icons.menu : Icons.arrow_back,
      actionIcon: Icons.swap_horiz_rounded,
      currentIndex: _tab.index,
      navItems: _navItems,
      onLeadingTap: () {
        if (_selectedOrder == null) {
          showRoleSwitchSheet(context, ref);
        } else {
          setState(() => _selectedOrder = null);
        }
      },
      onActionTap: () => context.go('/client'),
      onNavSelected: (index) {
        setState(() {
          _tab = ProductionTab.values[index];
          _selectedOrder = null;
        });
      },
      body: ordersAsync.when(
        data: (orders) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: _selectedOrder != null ? _detailView(_selectedOrder!) : _rootView(orders),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
      ),
    );
  }

  Widget _rootView(List<OrderModel> orders) {
    final accepted = orders.where((order) => order.status == OrderStatus.accepted).toList();
    final inProduction = orders.where((order) => order.status == OrderStatus.inProduction).toList();
    final ready = orders.where((order) => order.status == OrderStatus.ready).toList();
    final current = inProduction.isNotEmpty ? inProduction.first : (accepted.isNotEmpty ? accepted.first : null);

    return switch (_tab) {
      ProductionTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(
            'ОЧЕРЕДЬ ЗАДАЧ',
            'Цех получает заказ после подтверждения франчайзи и завершает цикл для клиента.',
            '${accepted.length + inProduction.length} ACTIVE',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metric('К ПОШИВУ', '${accepted.length}')),
              const SizedBox(width: 8),
              Expanded(child: _metric('В РАБОТЕ', '${inProduction.length}')),
              const SizedBox(width: 8),
              Expanded(child: _metric('ГОТОВО', '${ready.length}')),
            ],
          ),
          const SizedBox(height: 12),
          if (current != null) _taskCard(current),
        ],
      ),
      ProductionTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('К ПОШИВУ'),
          const SizedBox(height: 12),
          if (accepted.isEmpty) _empty('Франчайзи еще не передал новые задачи в цех.'),
          ...accepted.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _taskCard(order),
          )),
          const SizedBox(height: 8),
          _section('В РАБОТЕ'),
          const SizedBox(height: 12),
          if (inProduction.isEmpty) _empty('Активная работа появится после запуска пошива.'),
          ...inProduction.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _taskCard(order),
          )),
        ],
      ),
      ProductionTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('ЗАВЕРШЕННЫЕ'),
          const SizedBox(height: 12),
          if (ready.isEmpty) _empty('Как только мастер завершит заказ, он появится здесь.'),
          ...ready.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _taskCard(order),
          )),
        ],
      ),
      ProductionTab.station => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoleControlCard(currentRole: UserRole.production),
          const SizedBox(height: 12),
          _flatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('СТАНЦИЯ ЦЕХА', style: AppTypography.eyebrow),
                const SizedBox(height: 12),
                Text('Минимум текста, максимум контраста', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('Интерфейс мастера показывает только задачу, состояние и одно действие: взять в пошив или завершить.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AvishuButton(
            text: 'СМЕНИТЬ РОЛЬ',
            expanded: true,
            onPressed: () => showRoleSwitchSheet(context, ref),
          ),
        ],
      ),
    };
  }

  Widget _detailView(OrderModel order) {
    final isAccepted = order.status == OrderStatus.accepted;
    final isInProduction = order.status == OrderStatus.inProduction;
    final nextStatus = isAccepted ? OrderStatus.inProduction : OrderStatus.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ORDER #${order.id.substring(0, 6).toUpperCase()}', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text(order.productName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${order.sizeLabel} / \$${order.amount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: order.status.progressValue),
              const SizedBox(height: 10),
              Text(order.status.roleDescription, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isAccepted || isInProduction)
          AvishuButton(
            text: order.status.productionActionLabel,
            expanded: true,
            variant: AvishuButtonVariant.filled,
            onPressed: () async {
              await ref.read(orderRepositoryProvider).updateOrderStatus(order.id, nextStatus);
              if (mounted) {
                setState(() => _selectedOrder = null);
              }
            },
          ),
        if (order.status == OrderStatus.ready) ...[
          _empty('Клиент уже увидит этот заказ как "Готово" в мобильном трекинге.'),
          const SizedBox(height: 12),
          AvishuButton(
            text: 'ОТКРЫТЬ КЛИЕНТА',
            expanded: true,
            onPressed: () => context.go('/client'),
          ),
        ],
      ],
    );
  }

  Widget _taskCard(OrderModel order) {
    return _flatCard(
      onTap: () => setState(() => _selectedOrder = order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ORDER #${order.id.substring(0, 6).toUpperCase()}', style: AppTypography.eyebrow)),
              Text(order.status.panelLabel, style: AppTypography.code),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.productName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(order.status == OrderStatus.inProduction ? 'Активная задача мастера.' : 'Новая задача в очереди цеха.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text('ОТКРЫТЬ', style: AppTypography.button),
        ],
      ),
    );
  }

  Widget _hero(String title, String subtitle, String accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      color: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(accent, style: AppTypography.eyebrow.copyWith(color: AppColors.surfaceDim)),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.white)),
          const SizedBox(height: 12),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.surfaceHighest)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return _flatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _section(String label) => Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));

  Widget _empty(String text) => _flatCard(child: Text(text, style: Theme.of(context).textTheme.bodyMedium));

  Widget _flatCard({required Widget child, VoidCallback? onTap}) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
    return onTap == null ? card : InkWell(onTap: onTap, child: card);
  }
}
