import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _isSubmitting = false;
  bool _hasReadyBadge = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  AppLanguage get _language => ref.read(appSettingsProvider).language;

  String _t({required String ru, required String en, String? kk}) {
    return tr(_language, ru: ru, en: en, kk: kk);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(ru: 'ПАНЕЛЬ', en: 'HOME', kk: 'ПАНЕЛЬ'),
      icon: Icons.grid_view_rounded,
    ),
    AvishuNavItem(
      label: _t(ru: 'ПОТОК', en: 'FLOW', kk: 'АҒЫН'),
      icon: Icons.view_kanban_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ГОТОВО', en: 'READY', kk: 'ДАЙЫН'),
      icon: Icons.inventory_2_outlined,
      badge: _hasReadyBadge,
    ),
    AvishuNavItem(
      label: _t(ru: 'ПРОФИЛЬ', en: 'PROFILE', kk: 'ПРОФИЛЬ'),
      icon: Icons.person_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final ordersAsync = ref.watch(franchiseeOrdersProvider);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null
          ? _t(ru: 'ФРАНЧАЙЗИ / ЗАКАЗЫ', en: 'FRANCHISEE / ORDERS', kk: 'ФРАНЧАЙЗИ / ТАПСЫРЫСТАР')
          : _t(ru: 'ФРАНЧАЙЗИ / КАРТОЧКА', en: 'FRANCHISEE / DETAIL', kk: 'ФРАНЧАЙЗИ / КАРТОЧКА'),
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
          _tab = FranchiseeTab.values[index];
          _selectedOrder = null;
          if (_tab == FranchiseeTab.ready) _hasReadyBadge = false;
        });
      },
      body: ordersAsync.when(
        data: (orders) {
          // Show badge when there are ready orders the user hasn't seen yet
          final hasReady = orders.any(
            (o) => o.status == OrderStatus.ready,
          );
          if (hasReady && _tab != FranchiseeTab.ready && !_hasReadyBadge) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasReadyBadge = true);
            });
          } else if (!hasReady && _hasReadyBadge) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasReadyBadge = false);
            });
          }
          final selectedOrder = _resolveSelectedOrder(orders);
          return SingleChildScrollView(
            key: PageStorageKey('franchisee-${_tab.index}-${_selectedOrder?.id ?? 'none'}'),
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
            title: _t(ru: 'ПАНЕЛЬ ЗАКАЗОВ', en: 'ORDER DASHBOARD', kk: 'ТАПСЫРЫСТАР ПАНЕЛІ'),
            subtitle: _t(
              ru: 'Новые заказы появляются сразу после оплаты и могут быть переданы в производство без перезагрузки.',
              en: 'New orders appear right after payment and can be moved to production without reload.',
              kk: 'Жаңа тапсырыстар төлемнен кейін бірден пайда болады және қайта жүктеусіз өндіріске жіберілуі мүмкін.',
            ),
            accent: _t(
              ru: 'НОВЫХ МОДЕЛЕЙ: ${newOrders.length}',
              en: 'NEW ORDERS: ${newOrders.length}',
              kk: 'ЖАҢА ТАПСЫРЫСТАР: ${newOrders.length}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  _t(ru: 'Оборот', en: 'Revenue', kk: 'Айналым'),
                  revenue.toStringAsFixed(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'Новые', en: 'New', kk: 'Жаңа'),
                  '${newOrders.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'Готовы', en: 'Ready', kk: 'Дайын'),
                  '${readyOrders.length}',
                ),
              ),
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
          _sectionLabel(_t(ru: 'НОВЫЕ ЗАКАЗЫ', en: 'NEW ORDERS', kk: 'ЖАҢА ТАПСЫРЫСТАР')),
          const SizedBox(height: 12),
          if (newOrders.isEmpty)
            _emptyCard(
              _t(
                ru: 'Новые заказы пока не поступили.',
                en: 'No new orders yet.',
                kk: 'Жаңа тапсырыстар әлі түскен жоқ.',
              ),
            ),
          ...newOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
          const SizedBox(height: 4),
          _sectionLabel(_t(ru: 'ПЕРЕДАНО В ЦЕХ', en: 'SENT TO FACTORY', kk: 'ЦЕХКЕ ЖІБЕРІЛДІ')),
          const SizedBox(height: 12),
          if (queuedOrders.isEmpty)
            _emptyCard(
              _t(
                ru: 'После подтверждения заказ появится в очереди цеха.',
                en: 'Once accepted, the order will appear in the factory queue.',
                kk: 'Расталғаннан кейін тапсырыс цех кезегінде пайда болады.',
              ),
            ),
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
          _sectionLabel(_t(ru: 'ГОТОВО К ВЫДАЧЕ', en: 'READY FOR HANDOFF', kk: 'БЕРУГЕ ДАЙЫН')),
          const SizedBox(height: 12),
          if (readyOrders.isEmpty)
            _emptyCard(
              _t(
                ru: 'Готовые заказы появятся после завершения производства.',
                en: 'Ready orders will appear after production is completed.',
                kk: 'Дайын тапсырыстар өндіріс аяқталғаннан кейін пайда болады.',
              ),
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
              Text(
                _t(ru: 'КАБИНЕТ ФРАНЧАЙЗИ', en: 'FRANCHISEE DESK', kk: 'ФРАНЧАЙЗИ КАБИНЕТІ'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              Text(
                _t(ru: 'Управление заказами', en: 'Order Operations', kk: 'Тапсырыстарды басқару'),
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
                        '${_t(ru: 'РОЛЬ', en: 'ROLE')}: ${localizedRoleLabel(UserRole.franchisee, _language)}',
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
                  ru: 'В разделе доступны новые заказы, текущий поток производства и готовые позиции.',
                  en: 'This desk shows new orders, active production flow, and ready handoff items.',
                  kk: 'Бөлімде жаңа тапсырыстар, ағымдағы өндіріс барысы және дайын позициялар қолжетімді.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AvishuButton(
          text: _t(ru: 'ПОЧЕМУ AVISHU', en: 'WHY AVISHU', kk: 'НЕГЕ AVISHU'),
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.arrow_outward,
          onPressed: () => context.push('/why-avishu'),
        ),
        const SizedBox(height: 12),
        AvishuButton(
          text: _t(ru: 'ВЫЙТИ ИЗ АККАУНТА', en: 'SIGN OUT', kk: 'АККАУНТТАН ШЫҒУ'),
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
          title: _t(ru: 'ДЕТАЛИ ЗАКАЗА', en: 'ORDER DETAILS', kk: 'ТАПСЫРЫС МӘЛІМЕТТЕРІ'),
          rows: OrderSummaryRows.forOrder(order, language: _language),
        ),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(ru: 'КОММЕНТАРИЙ КЛИЕНТА', en: 'CLIENT COMMENT', kk: 'КЛИЕНТ ПІКІРІ'),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Комментарий', en: 'Comment', kk: 'Пікір'),
                value: order.clientNote,
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
                ru: 'Комментарий франчайзи',
                en: 'Franchisee Comment',
                kk: 'Франчайзи пікірі',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isNew)
          AvishuButton(
            text: _t(
              ru: 'ПРИНЯТЬ И ПЕРЕДАТЬ В ЦЕХ',
              en: 'ACCEPT AND SEND TO FACTORY',
              kk: 'ҚАБЫЛДАУ ЖӘНЕ ЦЕХКЕ ЖІБЕРУ',
            ),
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
                          .acceptOrder(
                            order.id,
                            note: _noteController.text.trim(),
                            changedByUserId: currentUserId,
                            franchiseeId: currentUserId,
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
          AvishuButton(
            text: _t(ru: 'ЗАВЕРШИТЬ ВЫДАЧУ', en: 'CONFIRM HANDOFF', kk: 'БЕРУДІ АЯҚТАУ'),
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
                          .finalizeOrder(
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
        if (!isNew && order.status != OrderStatus.ready)
          _surfaceCard(
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 16),
                const SizedBox(width: 10),
                Text(
                  _t(ru: 'ПЕРЕДАНО В ПРОИЗВОДСТВО', en: 'IN FACTORY QUEUE', kk: 'ӨНДІРІСКЕ ЖІБЕРІЛДІ'),
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
          Text(
            order.formattedAddress,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text(
            _t(ru: 'ОТКРЫТЬ КАРТОЧКУ', en: 'OPEN DETAIL', kk: 'КАРТОЧКАНЫ АШУ'),
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
    _noteController.text = order.franchiseeNote;
    setState(() => _selectedOrder = order);
  }
}
