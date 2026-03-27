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

final franchiseeOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).allOrders();
});

enum FranchiseeTab { dashboard, queue, ready, profile }

class FranchiseeDashboard extends ConsumerStatefulWidget {
  const FranchiseeDashboard({super.key});

  @override
  ConsumerState<FranchiseeDashboard> createState() => _FranchiseeDashboardState();
}

class _FranchiseeDashboardState extends ConsumerState<FranchiseeDashboard> {
  FranchiseeTab _tab = FranchiseeTab.dashboard;
  OrderModel? _selectedOrder;

  static const _navItems = [
    AvishuNavItem(label: 'ПАНЕЛЬ', icon: Icons.grid_view_rounded),
    AvishuNavItem(label: 'ПОТОК', icon: Icons.view_kanban_outlined),
    AvishuNavItem(label: 'ГОТОВО', icon: Icons.inventory_2_outlined),
    AvishuNavItem(label: 'ПРОФИЛЬ', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(franchiseeOrdersProvider);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null ? 'ФРАНЧАЙЗИ / ЗАКАЗЫ' : 'ФРАНЧАЙЗИ / КАРТОЧКА',
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
      onActionTap: () => context.go('/production'),
      onNavSelected: (index) {
        setState(() {
          _tab = FranchiseeTab.values[index];
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
    final newOrders = orders.where((order) => order.status == OrderStatus.newOrder).toList();
    final queuedOrders = orders.where((order) => order.status == OrderStatus.accepted).toList();
    final readyOrders = orders.where((order) => order.status == OrderStatus.ready).toList();
    final revenue = orders.fold<double>(0, (sum, order) => sum + order.amount);

    return switch (_tab) {
      FranchiseeTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(
            'ПАНЕЛЬ ЗАКАЗОВ',
            'Новые заказы появляются сразу после оплаты и могут быть переданы в производство без перезагрузки.',
            'НОВЫХ ЗАКАЗОВ: ${newOrders.length}',
          ),
          const SizedBox(height: 12),
          _metricRow([
            _metric('ОБОРОТ', '\$${revenue.toStringAsFixed(0)}'),
            _metric('НОВЫЕ', '${newOrders.length}'),
            _metric('ГОТОВЫЕ', '${readyOrders.length}'),
          ]),
          const SizedBox(height: 12),
          if (newOrders.isNotEmpty) _orderCard(newOrders.first),
          if (queuedOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _orderCard(queuedOrders.first),
          ],
        ],
      ),
      FranchiseeTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('НОВЫЕ ЗАКАЗЫ'),
          const SizedBox(height: 12),
          if (newOrders.isEmpty) _empty('Новые заказы появятся здесь сразу после оплаты клиента.'),
          ...newOrders.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(order),
          )),
          const SizedBox(height: 8),
          _section('В ПОТОКЕ ЦЕХА'),
          const SizedBox(height: 12),
          if (queuedOrders.isEmpty) _empty('После принятия заказ уходит в очередь производства.'),
          ...queuedOrders.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(order),
          )),
        ],
      ),
      FranchiseeTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('ГОТОВЫЕ К ВЫДАЧЕ'),
          const SizedBox(height: 12),
          if (readyOrders.isEmpty) _empty('Когда цех завершит заказ, он появится в этом списке.'),
          ...readyOrders.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(order),
          )),
        ],
      ),
      FranchiseeTab.profile => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoleControlCard(currentRole: UserRole.franchisee),
          const SizedBox(height: 12),
          _flatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ФРАНШИЗА', style: AppTypography.eyebrow),
                const SizedBox(height: 12),
                Text('Кабинет франчайзи', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('Здесь собраны заказы клиентов, текущий поток производства и готовые позиции.', style: Theme.of(context).textTheme.bodyMedium),
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
    final isNew = order.status == OrderStatus.newOrder;
    final canJumpToProduction = order.status == OrderStatus.accepted || order.status == OrderStatus.inProduction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ЗАКАЗ #${order.id.substring(0, 6).toUpperCase()}', style: AppTypography.eyebrow),
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
        if (isNew)
          AvishuButton(
            text: 'ПРИНЯТЬ И ОТПРАВИТЬ В ЦЕХ',
            expanded: true,
            variant: AvishuButtonVariant.filled,
            onPressed: () async {
              await ref.read(orderRepositoryProvider).updateOrderStatus(order.id, OrderStatus.accepted);
              if (mounted) {
                setState(() => _selectedOrder = null);
              }
            },
          ),
        if (!isNew) ...[
          _flatCard(
            child: Text(
              canJumpToProduction
                  ? 'Этот заказ уже находится в очереди или в пошиве. Можно открыть роль производства и продолжить сценарий.'
                  : 'Заказ завершен. Клиент видит статус "Готово" в своем мобильном трекинге.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          AvishuButton(
            text: canJumpToProduction ? 'ОТКРЫТЬ ПРОИЗВОДСТВО' : 'ВЕРНУТЬСЯ К СПИСКУ',
            expanded: true,
            onPressed: () {
              if (canJumpToProduction) {
                context.go('/production');
              } else {
                setState(() => _selectedOrder = null);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _orderCard(OrderModel order) {
    return _flatCard(
      onTap: () => setState(() => _selectedOrder = order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ЗАКАЗ #${order.id.substring(0, 6).toUpperCase()}', style: AppTypography.eyebrow)),
              Text(order.status.panelLabel, style: AppTypography.code),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.productName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(order.status.roleDescription, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text('ОТКРЫТЬ КАРТОЧКУ', style: AppTypography.button),
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

  Widget _metricRow(List<Widget> children) {
    return Row(
      children: children
          .map((child) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child)))
          .toList(),
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
