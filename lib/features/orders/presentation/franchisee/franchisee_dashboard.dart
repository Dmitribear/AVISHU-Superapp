import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../shared/order_digital_twin_card.dart';
import '../shared/order_panels.dart';

final franchiseeOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).ordersByStatuses(const [
    OrderStatus.newOrder,
    OrderStatus.accepted,
    OrderStatus.inProduction,
    OrderStatus.ready,
  ]);
});

enum FranchiseeTab { dashboard, queue, ready, profile }

class FranchiseeDashboard extends ConsumerStatefulWidget {
  const FranchiseeDashboard({super.key});

  @override
  ConsumerState<FranchiseeDashboard> createState() =>
      _FranchiseeDashboardState();
}

class _FranchiseeDashboardState extends ConsumerState<FranchiseeDashboard> {
  FranchiseeTab _tab = FranchiseeTab.dashboard;
  OrderModel? _selectedOrder;
  final _noteController = TextEditingController();

  static const _navItems = [
    AvishuNavItem(label: 'ПАНЕЛЬ', icon: Icons.grid_view_rounded),
    AvishuNavItem(label: 'ПОТОК', icon: Icons.view_kanban_outlined),
    AvishuNavItem(label: 'ГОТОВО', icon: Icons.inventory_2_outlined),
    AvishuNavItem(label: 'ПРОФИЛЬ', icon: Icons.person_outline),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(franchiseeOrdersProvider);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null
          ? 'ФРАНЧАЙЗИ / ЗАКАЗЫ'
          : 'ФРАНЧАЙЗИ / КАРТОЧКА',
      leadingIcon: _selectedOrder == null ? Icons.menu : Icons.arrow_back,
      actionIcon: Icons.precision_manufacturing_outlined,
      currentIndex: _tab.index,
      navItems: _navItems,
      onLeadingTap: () {
        if (_selectedOrder == null) {
          showAppSettingsSheet(context);
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
        data: (orders) {
          final selectedOrder = _resolveSelectedOrder(orders);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: _selectedOrder != null
                ? _detailView(selectedOrder ?? _selectedOrder!)
                : _rootView(orders),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
      ),
    );
  }

  Widget _rootView(List<OrderModel> orders) {
    final newOrders = orders
        .where((order) => order.status == OrderStatus.newOrder)
        .toList();
    final queuedOrders = orders
        .where((order) => order.status == OrderStatus.accepted)
        .toList();
    final readyOrders = orders
        .where((order) => order.status == OrderStatus.ready)
        .toList();
    final revenue = orders.fold<double>(0, (sum, order) => sum + order.amount);

    return switch (_tab) {
      FranchiseeTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(
            title: 'ПАНЕЛЬ ЗАКАЗОВ',
            subtitle:
                'Новые заказы появляются сразу после оплаты и могут быть переданы в производство без перезагрузки.',
            accent: 'НОВЫХ ЗАКАЗОВ: ${newOrders.length}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard('Оборот', revenue.toStringAsFixed(0)),
              ),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Новые', '${newOrders.length}')),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Готовы', '${readyOrders.length}')),
            ],
          ),
          const SizedBox(height: 12),
          ...[...newOrders.take(2), ...queuedOrders.take(1)].map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
        ],
      ),
      FranchiseeTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('НОВЫЕ ЗАКАЗЫ'),
          const SizedBox(height: 12),
          if (newOrders.isEmpty) _emptyCard('Новые заказы пока не поступили.'),
          ...newOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
          const SizedBox(height: 4),
          _sectionLabel('ПЕРЕДАНО В ЦЕХ'),
          const SizedBox(height: 12),
          if (queuedOrders.isEmpty)
            _emptyCard('После подтверждения заказ появится в очереди цеха.'),
          ...queuedOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
        ],
      ),
      FranchiseeTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ГОТОВО К ВЫДАЧЕ'),
          const SizedBox(height: 12),
          if (readyOrders.isEmpty)
            _emptyCard(
              'Готовые заказы появятся после завершения производства.',
            ),
          ...readyOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
        ],
      ),
      FranchiseeTab.profile => _buildProfileTab(),
    };
  }

  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('КАБИНЕТ ФРАНЧАЙЗИ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text(
                'Управление заказами',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border.all(color: AppColors.black),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'РОЛЬ: ФРАНЧАЙЗИ',
                        style: AppTypography.button.copyWith(
                          color: AppColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    Text(
                      'ТЕКУЩАЯ',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'В разделе доступны новые заказы, текущий поток производства и готовые позиции.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AvishuButton(
          text: 'ВЫЙТИ ИЗ АККАУНТА',
          expanded: true,
          variant: AvishuButtonVariant.outline,
          icon: Icons.logout,
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
      ],
    );
  }

  Widget _detailView(OrderModel order) {
    final isNew = order.status == OrderStatus.newOrder;
    final canOpenProduction =
        order.status == OrderStatus.accepted ||
        order.status == OrderStatus.inProduction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderDigitalTwinCard(order: order),
        const SizedBox(height: 12),
        if (order.id.isEmpty)
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ЗАКАЗ #${order.shortId}', style: AppTypography.eyebrow),
                const SizedBox(height: 12),
                Text(
                  order.productName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  order.status.roleDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: order.status.progressValue),
                const SizedBox(height: 10),
                Text(order.status.panelLabel, style: AppTypography.code),
              ],
            ),
          ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: 'ДЕТАЛИ ЗАКАЗА',
          rows: OrderSummaryRows.forOrder(order),
        ),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: 'КОММЕНТАРИЙ КЛИЕНТА',
            rows: [
              OrderInfoRowData(label: 'Комментарий', value: order.clientNote),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _surfaceCard(
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Комментарий франчайзи',
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isNew)
          AvishuButton(
            text: 'ПРИНЯТЬ И ПЕРЕДАТЬ В ЦЕХ',
            expanded: true,
            variant: AvishuButtonVariant.filled,
            onPressed: () async {
              final currentUserId =
                  ref.read(currentUserProvider).value?.uid ?? '';
              await ref
                  .read(orderRepositoryProvider)
                  .acceptOrder(
                    order.id,
                    note: _noteController.text.trim(),
                    changedByUserId: currentUserId,
                    franchiseeId: currentUserId,
                  );
              if (mounted) {
                setState(() => _selectedOrder = null);
              }
            },
          ),
        if (!isNew)
          AvishuButton(
            text: canOpenProduction ? 'ОТКРЫТЬ ПРОИЗВОДСТВО' : 'ЗАКАЗ ЗАВЕРШЕН',
            expanded: true,
            onPressed: canOpenProduction
                ? () => context.go('/production')
                : null,
          ),
      ],
    );
  }

  Widget _hero({
    required String title,
    required String subtitle,
    required String accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      color: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accent,
            style: AppTypography.eyebrow.copyWith(color: AppColors.surfaceDim),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.surfaceHighest),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _orderCard(OrderModel order) {
    return _surfaceCard(
      onTap: () => _openOrder(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ЗАКАЗ #${order.shortId}',
                  style: AppTypography.eyebrow,
                ),
              ),
              Text(order.status.panelLabel, style: AppTypography.code),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.productName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            order.formattedAddress,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text('ОТКРЫТЬ КАРТОЧКУ', style: AppTypography.button),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, VoidCallback? onTap}) {
    final compact = ref.watch(appSettingsProvider).compactCards;
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
    return onTap == null ? card : InkWell(onTap: onTap, child: card);
  }

  Widget _emptyCard(String text) {
    return _surfaceCard(
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));
  }

  OrderModel? _resolveSelectedOrder(List<OrderModel> orders) {
    final selectedOrder = _selectedOrder;
    if (selectedOrder == null) {
      return null;
    }

    for (final order in orders) {
      if (order.id == selectedOrder.id) {
        return order;
      }
    }
    return selectedOrder;
  }

  void _openOrder(OrderModel order) {
    _noteController.text = order.franchiseeNote;
    setState(() => _selectedOrder = order);
  }
}
