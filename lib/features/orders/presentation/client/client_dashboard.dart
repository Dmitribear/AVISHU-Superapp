import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../shared/widgets/role_switch_sheet.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import 'client_data.dart';

final clientOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  clientId,
) {
  return ref.watch(orderRepositoryProvider).clientOrders(clientId);
});

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard> {
  ClientTab _tab = ClientTab.dashboard;
  ClientView _view = ClientView.root;
  CatalogProduct? _selectedProduct;
  DateTime? _selectedDate;
  String? _latestOrderId;
  bool _courierDelivery = true;

  final _cityController = TextEditingController(text: 'АЛМАТЫ');
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController(text: '01 / 28');
  final _cvvController = TextEditingController();

  static const _navItems = [
    AvishuNavItem(label: 'ПАНЕЛЬ', icon: Icons.grid_view_rounded),
    AvishuNavItem(label: 'КОЛЛЕКЦИИ', icon: Icons.layers_outlined),
    AvishuNavItem(label: 'АРХИВ', icon: Icons.inventory_2_outlined),
    AvishuNavItem(label: 'ПРОФИЛЬ', icon: Icons.person_outline),
  ];

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final ordersAsync = ref.watch(clientOrdersProvider(user.uid));
    final trackedOrder = ordersAsync.value == null
        ? null
        : resolveTrackedOrder(ordersAsync.value!, _latestOrderId);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _metaLabel,
      leadingIcon: _view == ClientView.root ? Icons.menu : Icons.arrow_back,
      actionIcon: trackedOrder == null
          ? Icons.shopping_bag_outlined
          : Icons.local_shipping_outlined,
      currentIndex: _tab.index,
      navItems: _navItems,
      onLeadingTap: () {
        if (_view == ClientView.root) {
          showRoleSwitchSheet(context, ref);
        } else {
          setState(() => _view = ClientView.root);
        }
      },
      onActionTap: () {
        setState(() {
          if (trackedOrder != null) {
            _tab = ClientTab.dashboard;
            _view = ClientView.tracking;
          } else {
            _tab = ClientTab.collections;
            _view = ClientView.root;
          }
        });
      },
      onNavSelected: (index) {
        setState(() {
          _tab = ClientTab.values[index];
          _view = ClientView.root;
        });
      },
      body: ordersAsync.when(
        data: (orders) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: _buildScreen(context, orders, user.uid, user.role, trackedOrder),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
      ),
    );
  }

  String get _metaLabel {
    switch (_view) {
      case ClientView.product:
        return 'КЛИЕНТ / ТОВАР';
      case ClientView.checkout:
        return 'КЛИЕНТ / ОФОРМЛЕНИЕ';
      case ClientView.payment:
        return 'КЛИЕНТ / ОПЛАТА';
      case ClientView.tracking:
        return 'КЛИЕНТ / ОТСЛЕЖИВАНИЕ';
      case ClientView.root:
        return switch (_tab) {
          ClientTab.dashboard => 'КЛИЕНТ / ГЛАВНАЯ',
          ClientTab.collections => 'КЛИЕНТ / КОЛЛЕКЦИИ',
          ClientTab.archive => 'КЛИЕНТ / ИСТОРИЯ',
          ClientTab.profile => 'КЛИЕНТ / ПРОФИЛЬ',
        };
    }
  }

  Widget _buildScreen(
    BuildContext context,
    List<OrderModel> orders,
    String clientId,
    UserRole currentRole,
    OrderModel? trackedOrder,
  ) {
    if (_view == ClientView.product && _selectedProduct != null) {
      return _buildProductScreen();
    }
    if (_view == ClientView.checkout && _selectedProduct != null) {
      return _buildCheckoutScreen();
    }
    if (_view == ClientView.payment && _selectedProduct != null) {
      return _buildPaymentScreen(clientId);
    }
    if (_view == ClientView.tracking) {
      return _buildTrackingScreen(trackedOrder);
    }

    return switch (_tab) {
      ClientTab.dashboard => _buildDashboardScreen(orders),
      ClientTab.collections => _buildCollectionsScreen(),
      ClientTab.archive => _buildArchiveScreen(orders),
      ClientTab.profile => _buildProfileScreen(orders, currentRole, trackedOrder),
    };
  }

  Widget _buildDashboardScreen(List<OrderModel> orders) {
    final activeOrder = resolveTrackedOrder(orders, _latestOrderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          title: 'АКТУАЛЬНАЯ КОЛЛЕКЦИЯ',
          subtitle: 'Выберите изделие, оформите заказ и отслеживайте его статус в приложении.',
          accent: 'АКТИВНЫХ ЗАКАЗОВ: ${orders.length.toString().padLeft(2, '0')}',
        ),
        const SizedBox(height: 18),
        if (activeOrder != null) _orderCard(activeOrder, cta: 'ОТСЛЕДИТЬ', onTap: () {
          setState(() {
            _latestOrderId = activeOrder.id;
            _view = ClientView.tracking;
          });
        }),
        if (activeOrder == null)
          _flatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('АКТИВНЫЙ ЗАКАЗ', style: AppTypography.eyebrow),
                const SizedBox(height: 12),
                Text('Пока нет заказов', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('Откройте коллекции, выберите изделие и пройдите сценарий оплаты.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        const SizedBox(height: 18),
        _sectionLabel('КЛИКАБЕЛЬНЫЕ ИЗДЕЛИЯ'),
        const SizedBox(height: 12),
        ...catalog.take(2).map((product) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _productCard(product, onTap: () => _openProduct(product)),
        )),
      ],
    );
  }

  Widget _buildCollectionsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('КОЛЛЕКЦИИ'),
        const SizedBox(height: 12),
        ...archiveCollections.take(3).map((collection) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _flatCard(
            onTap: () => _openProduct(catalog.first),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${collection.year} / ${collection.season}', style: AppTypography.eyebrow),
                      const SizedBox(height: 10),
                      Text(collection.title, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
                Text(collection.released ? 'АКТИВНАЯ' : 'АРХИВ', style: AppTypography.code),
              ],
            ),
          ),
        )),
        const SizedBox(height: 10),
        ...catalog.map((product) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _productCard(product, onTap: () => _openProduct(product)),
        )),
      ],
    );
  }

  Widget _buildArchiveScreen(List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ИСТОРИЯ ЗАКАЗОВ'),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _flatCard(
            child: Text('История появится после первой оплаты.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ...orders.map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _orderCard(order, cta: 'ДЕТАЛИ', onTap: () {
            setState(() {
              _latestOrderId = order.id;
              _view = ClientView.tracking;
            });
          }),
        )),
      ],
    );
  }

  Widget _buildProfileScreen(
    List<OrderModel> orders,
    UserRole currentRole,
    OrderModel? trackedOrder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoleControlCard(currentRole: currentRole),
        const SizedBox(height: 12),
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ПРОФИЛЬ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text('ПЕРСОНАЛЬНЫЙ КЛИЕНТ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: ((orders.length % 4) + 1) / 4),
              const SizedBox(height: 10),
              Text('ЗАКАЗОВ: ${orders.length} / СЛЕДУЮЩИЙ УРОВЕНЬ: ПРИОРИТЕТ', style: AppTypography.code),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (trackedOrder != null)
          _orderCard(trackedOrder, cta: 'ТРЕКИНГ', onTap: () {
            setState(() => _view = ClientView.tracking);
          }),
      ],
    );
  }

  Widget _buildProductScreen() {
    final product = _selectedProduct!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 320,
          width: double.infinity,
          color: AppColors.surfaceHigh,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.preorder ? 'СТАТУС: ПРЕДЗАКАЗ' : 'СТАТУС: В НАЛИЧИИ', style: AppTypography.eyebrow.copyWith(color: AppColors.white)),
              const Spacer(),
              Text(product.title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.sku, style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text('${product.material} / ${product.sizeLabel}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(product.description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (product.preorder) ...[
          const SizedBox(height: 12),
          _sectionLabel('ДАТА ГОТОВНОСТИ'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dateOptions.map((date) => ChoiceChip(
              label: Text('${monthShort(date.month)} ${date.day.toString().padLeft(2, '0')}'),
              selected: _selectedDate == date,
              onSelected: (_) => setState(() => _selectedDate = date),
            )).toList(),
          ),
        ],
        const SizedBox(height: 18),
        AvishuButton(
          text: product.preorder ? 'ОФОРМИТЬ ПРЕДЗАКАЗ' : 'ОФОРМИТЬ ЗАКАЗ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () {
            setState(() {
              _view = ClientView.checkout;
              _courierDelivery = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCheckoutScreen() {
    final product = _selectedProduct!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('АДРЕС ДОСТАВКИ'),
        const SizedBox(height: 12),
        _flatCard(
          child: Column(
            children: [
              TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'ГОРОД')),
              const SizedBox(height: 12),
              TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'АДРЕС')),
              const SizedBox(height: 12),
              TextField(controller: _apartmentController, decoration: const InputDecoration(labelText: 'КВАРТИРА / ОФИС')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionLabel('СПОСОБ ПОЛУЧЕНИЯ'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _deliveryCard('КУРЬЕР', _courierDelivery, () => setState(() => _courierDelivery = true))),
            const SizedBox(width: 10),
            Expanded(child: _deliveryCard('САМОВЫВОЗ', !_courierDelivery, () => setState(() => _courierDelivery = false))),
          ],
        ),
        const SizedBox(height: 18),
        _summaryCard(product),
        const SizedBox(height: 18),
        AvishuButton(
          text: 'К ОПЛАТЕ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () => setState(() => _view = ClientView.payment),
        ),
      ],
    );
  }

  Widget _buildPaymentScreen(String clientId) {
    final product = _selectedProduct!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ДАННЫЕ КАРТЫ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              TextField(controller: _cardController, decoration: const InputDecoration(labelText: 'НОМЕР КАРТЫ')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _expiryController, decoration: const InputDecoration(labelText: 'MM / YY'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _cvvController, decoration: const InputDecoration(labelText: 'CVV'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _summaryCard(product),
        const SizedBox(height: 18),
        AvishuButton(
          text: 'ОПЛАТИТЬ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () async {
            final orderId = await ref.read(orderRepositoryProvider).createOrder(
              clientId: clientId,
              productName: product.title,
              sizeLabel: product.sizeLabel,
              amount: _totalPrice(product),
              isPreorder: product.preorder,
              readyBy: product.preorder ? _selectedDate : null,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _latestOrderId = orderId;
              _view = ClientView.tracking;
              _tab = ClientTab.dashboard;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTrackingScreen(OrderModel? order) {
    if (order == null) {
      return _flatCard(
        child: Text('Ожидаем синхронизацию заказа с витриной.', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ТРЕКИНГ ЗАКАЗА', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text('ЗАКАЗ #${order.id.substring(0, 6).toUpperCase()}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(order.productName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(order.status.roleDescription, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              LinearProgressIndicator(value: order.status.progressValue),
              const SizedBox(height: 10),
              Text('СТАТУС / ${order.status.clientLabel}', style: AppTypography.code),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _flatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('СВЯЗАННЫЕ РОЛИ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text('Франчайзи видит заказ сразу после оплаты, а цех получает его после подтверждения.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AvishuButton(
                      text: 'СМЕНИТЬ РОЛЬ',
                      onPressed: () => showRoleSwitchSheet(context, ref),
                      variant: AvishuButtonVariant.ghost,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: AvishuButton(text: 'КОЛЛЕКЦИИ', onPressed: () {
                    setState(() {
                      _tab = ClientTab.collections;
                      _view = ClientView.root;
                    });
                  })),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openProduct(CatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _selectedDate = product.preorder ? dateOptions[1] : null;
      _view = ClientView.product;
    });
  }

  double _totalPrice(CatalogProduct product) => product.price + (_courierDelivery ? 25 : 0);

  Widget _heroCard({required String title, required String subtitle, required String accent}) {
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

  Widget _summaryCard(CatalogProduct product) {
    return _flatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('СОСТАВ ЗАКАЗА', style: AppTypography.eyebrow),
          const SizedBox(height: 12),
          _summaryRow(product.title, '\$${product.price.toStringAsFixed(0)}'),
          _summaryRow(_courierDelivery ? 'Курьер' : 'Самовывоз', _courierDelivery ? '\$25' : '\$0'),
          if (product.preorder && _selectedDate != null) _summaryRow('Готовность', formatDate(_selectedDate!)),
          const Divider(height: 24),
          _summaryRow('ИТОГО', '\$${_totalPrice(product).toStringAsFixed(0)}', strong: true),
        ],
      ),
    );
  }

  Widget _productCard(CatalogProduct product, {required VoidCallback onTap}) {
    return _flatCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(width: 76, height: 104, color: product.preorder ? AppColors.surfaceHigh : AppColors.surfaceLow),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(product.material, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                const SizedBox(height: 8),
                Text('${product.preorder ? 'ПРЕДЗАКАЗ' : 'В НАЛИЧИИ'} / ${product.sizeLabel}', style: AppTypography.code),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('\$${product.price.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _orderCard(OrderModel order, {required String cta, required VoidCallback onTap}) {
    return _flatCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ЗАКАЗ #${order.id.substring(0, 6).toUpperCase()}', style: AppTypography.eyebrow)),
              Text(order.status.panelLabel, style: AppTypography.code),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.productName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${order.sizeLabel} / \$${order.amount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text(cta, style: AppTypography.button),
        ],
      ),
    );
  }

  Widget _deliveryCard(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('СПОСОБ', style: AppTypography.eyebrow.copyWith(color: active ? AppColors.surfaceDim : AppColors.outline)),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: active ? AppColors.white : AppColors.black)),
          ],
        ),
      ),
    );
  }

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
    if (onTap == null) {
      return card;
    }
    return InkWell(onTap: onTap, child: card);
  }

  Widget _sectionLabel(String label) => Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));

  Widget _summaryRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: strong ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
