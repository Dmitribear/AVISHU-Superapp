import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../shared/order_digital_twin_card.dart';
import '../shared/order_panels.dart';

final productionAllOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).productionQueue();
});

enum ProductionTab { dashboard, queue, ready, station }

class ProductionDashboard extends ConsumerStatefulWidget {
  const ProductionDashboard({super.key});

  @override
  ConsumerState<ProductionDashboard> createState() =>
      _ProductionDashboardState();
}

class _ProductionDashboardState extends ConsumerState<ProductionDashboard> {
  ProductionTab _tab = ProductionTab.dashboard;
  OrderModel? _selectedOrder;
  bool _isSubmitting = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  AppLanguage get _language => ref.read(appSettingsProvider).language;

  String _t({required String ru, required String en}) {
    return tr(_language, ru: ru, en: en);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(ru: 'ОБЗОР', en: 'OVERVIEW'),
      icon: Icons.dashboard_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ОЧЕРЕДЬ', en: 'QUEUE'),
      icon: Icons.format_list_bulleted_rounded,
    ),
    AvishuNavItem(
      label: _t(ru: 'ГОТОВО', en: 'READY'),
      icon: Icons.checkroom_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'СТАНЦИЯ', en: 'STATION'),
      icon: Icons.precision_manufacturing_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final ordersAsync = ref.watch(productionAllOrdersProvider);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null
          ? _t(ru: 'ПРОИЗВОДСТВО / ОЧЕРЕДЬ', en: 'FACTORY / QUEUE')
          : _t(ru: 'ПРОИЗВОДСТВО / ЗАДАЧА', en: 'FACTORY / TASK'),
      leadingIcon: _selectedOrder == null ? Icons.menu : Icons.arrow_back,
      actionIcon: null,
      currentIndex: _tab.index,
      navItems: _navItems,
      onLeadingTap: () {
        if (_selectedOrder == null) {
          showAppSettingsSheet(context);
        } else {
          setState(() => _selectedOrder = null);
        }
      },
      onActionTap: null,
      onNavSelected: (index) {
        setState(() {
          _tab = ProductionTab.values[index];
          _selectedOrder = null;
        });
      },
      body: ordersAsync.when(
        data: (orders) {
          final selectedOrder = _resolveSelectedOrder(orders);
          return SingleChildScrollView(
            key: PageStorageKey('production-${_tab.index}-${_selectedOrder?.id ?? 'none'}'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: _selectedOrder != null
                ? _detailView(selectedOrder ?? _selectedOrder!)
                : _rootView(orders),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, _) => Center(
          child: Text(
            _t(ru: 'Ошибка загрузки: $err', en: 'Loading error: $err'),
          ),
        ),
      ),
    );
  }

  Widget _rootView(List<OrderModel> orders) {
    final accepted = orders
        .where((order) => order.status == OrderStatus.accepted)
        .toList();
    final inProduction = orders
        .where((order) => order.status == OrderStatus.inProduction)
        .toList();
    final ready = orders
        .where((order) => order.status == OrderStatus.ready)
        .toList();
    final current = inProduction.isNotEmpty
        ? inProduction.first
        : (accepted.isNotEmpty ? accepted.first : null);

    return switch (_tab) {
      ProductionTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(
            title: _t(ru: 'ОЧЕРЕДЬ ЗАДАЧ', en: 'TASK QUEUE'),
            subtitle: _t(
              ru: 'После подтверждения заказ попадает в очередь цеха и проходит этапы пошива до готовности.',
              en: 'After acceptance, the order enters the factory queue and moves through production until ready.',
            ),
            accent: _t(
              ru: 'АКТИВНЫХ ЗАДАЧ: ${accepted.length + inProduction.length}',
              en: 'ACTIVE TASKS: ${accepted.length + inProduction.length}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  _t(ru: 'К пошиву', en: 'To Tailor'),
                  '${accepted.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'В работе', en: 'In Progress'),
                  '${inProduction.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'Готово', en: 'Ready'),
                  '${ready.length}',
                ),
              ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 12),
            _taskCard(current),
          ],
        ],
      ),
      ProductionTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(_t(ru: 'К ПОШИВУ', en: 'TO TAILOR')),
          const SizedBox(height: 12),
          if (accepted.isEmpty)
            _emptyCard(
              _t(
                ru: 'Новых задач в очереди пока нет.',
                en: 'No new tasks in queue yet.',
              ),
            ),
          ...accepted.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(order),
            ),
          ),
          const SizedBox(height: 4),
          _sectionLabel(_t(ru: 'В РАБОТЕ', en: 'IN PROGRESS')),
          const SizedBox(height: 12),
          if (inProduction.isEmpty)
            _emptyCard(
              _t(
                ru: 'После запуска пошива заказ перейдет в этот раздел.',
                en: 'Once production starts, the order will appear in this section.',
              ),
            ),
          ...inProduction.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(order),
            ),
          ),
        ],
      ),
      ProductionTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(_t(ru: 'ЗАВЕРШЕННЫЕ', en: 'COMPLETED READY')),
          const SizedBox(height: 12),
          if (ready.isEmpty)
            _emptyCard(
              _t(
                ru: 'Завершенные заказы пока отсутствуют.',
                en: 'No completed ready orders yet.',
              ),
            ),
          ...ready.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(order),
            ),
          ),
        ],
      ),
      ProductionTab.station => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(ru: 'РАБОЧЕЕ МЕСТО', en: 'WORKSTATION'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(ru: 'Интерфейс мастера', en: 'Operator Interface'),
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
                          '${_t(ru: 'РОЛЬ', en: 'ROLE')}: ${localizedRoleLabel(UserRole.production, _language)}',
                          style: AppTypography.button.copyWith(
                            color: AppColors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      Text(
                        _t(ru: 'ТЕКУЩАЯ', en: 'CURRENT'),
                        style: AppTypography.eyebrow.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    ru: 'Экран показывает текущую задачу, статус заказа и следующее доступное действие.',
                    en: 'This screen shows the current task, order status, and the next available action.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AvishuButton(
            text: _t(ru: 'ВЫЙТИ ИЗ АККАУНТА', en: 'SIGN OUT'),
            expanded: true,
            variant: AvishuButtonVariant.outline,
            icon: Icons.logout,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    };
  }

  Widget _detailView(OrderModel order) {
    final isAccepted = order.status == OrderStatus.accepted;
    final isInProduction = order.status == OrderStatus.inProduction;

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
                Text(
                  '${_t(ru: 'ЗАКАЗ', en: 'ORDER')} #${order.shortId}',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  order.productName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  order.status.roleDescriptionFor(_language),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: order.status.progressValue),
                const SizedBox(height: 10),
                Text(
                  order.status.panelLabelFor(_language),
                  style: AppTypography.code,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: _t(ru: 'ТЕХНИЧЕСКАЯ КАРТОЧКА', en: 'TECHNICAL SHEET'),
          rows: OrderSummaryRows.forOrder(order, language: _language),
        ),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(ru: 'КОММЕНТАРИЙ КЛИЕНТА', en: 'CLIENT COMMENT'),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Комментарий', en: 'Comment'),
                value: order.clientNote,
              ),
            ],
          ),
        ],
        if (order.franchiseeNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(ru: 'ПОМЕТКА ФРАНЧАЙЗИ', en: 'FRANCHISE NOTE'),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Комментарий', en: 'Comment'),
                value: order.franchiseeNote,
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _surfaceCard(
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _t(
                ru: 'Комментарий производства',
                en: 'Factory Comment',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isAccepted)
          AvishuButton(
            text: _t(ru: 'ВЗЯТЬ В ПОШИВ', en: 'START PRODUCTION'),
            expanded: true,
            variant: AvishuButtonVariant.filled,
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_isSubmitting) return;
                    setState(() => _isSubmitting = true);
                    try {
                      final currentUserId =
                          ref.read(currentUserProvider).value?.uid ?? '';
                      await ref
                          .read(orderRepositoryProvider)
                          .startProduction(
                            order.id,
                            note: _noteController.text.trim(),
                            changedByUserId: currentUserId,
                          );
                      if (mounted) {
                        setState(() => _selectedOrder = null);
                      }
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
          ),
        if (isInProduction)
          AvishuButton(
            text: _t(ru: 'ЗАВЕРШИТЬ ПОШИВ', en: 'FINISH PRODUCTION'),
            expanded: true,
            variant: AvishuButtonVariant.filled,
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_isSubmitting) return;
                    setState(() => _isSubmitting = true);
                    try {
                      final currentUserId =
                          ref.read(currentUserProvider).value?.uid ?? '';
                      await ref
                          .read(orderRepositoryProvider)
                          .completeOrder(
                            order.id,
                            note: _noteController.text.trim(),
                            changedByUserId: currentUserId,
                          );
                      if (mounted) {
                        setState(() => _selectedOrder = null);
                      }
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
          ),
        if (order.status == OrderStatus.ready)
          _surfaceCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16),
                const SizedBox(width: 10),
                Text(
                  _t(
                    ru: 'ГОТОВО. ОЖИДАЕТ ВЫДАЧИ ФРАНЧАЙЗИ.',
                    en: 'READY. AWAITING FRANCHISEE HANDOFF.',
                  ),
                  style: AppTypography.code,
                ),
              ],
            ),
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

  Widget _taskCard(OrderModel order) {
    return _surfaceCard(
      onTap: () => _openOrder(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_t(ru: 'ЗАКАЗ', en: 'ORDER')} #${order.shortId}',
                  style: AppTypography.eyebrow,
                ),
              ),
              Text(
                order.status.panelLabelFor(_language),
                style: AppTypography.code,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.productName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(order.sizeLabel, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text(
            _t(ru: 'ОТКРЫТЬ', en: 'OPEN'),
            style: AppTypography.button,
          ),
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
    _noteController.text = order.productionNote;
    setState(() => _selectedOrder = order);
  }
}
