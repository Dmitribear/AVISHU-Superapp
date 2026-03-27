import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../shared/widgets/role_switch_sheet.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/delivery_method.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../shared/order_formatters.dart';
import '../shared/order_panels.dart';
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
  DeliveryMethod _deliveryMethod = DeliveryMethod.courier;

  final _cityController = TextEditingController(text: 'Алматы');
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController(text: '01 / 28');
  final _cvvController = TextEditingController();
  final _noteController = TextEditingController();

  static const _navItems = [
    AvishuNavItem(label: 'ПАНЕЛЬ', icon: Icons.grid_view_rounded),
    AvishuNavItem(label: 'КОЛЛЕКЦИИ', icon: Icons.layers_outlined),
    AvishuNavItem(label: 'ИСТОРИЯ', icon: Icons.inventory_2_outlined),
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
    _noteController.dispose();
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
          showAppSettingsSheet(context);
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
          child: _buildScreen(
            context,
            orders,
            user.uid,
            user.role,
            trackedOrder,
          ),
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
    final preorderCount = orders.where((order) => order.isPreorder).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          title: 'АКТУАЛЬНАЯ КОЛЛЕКЦИЯ',
          subtitle:
              'Выберите изделие, оформите заказ и отслеживайте его статус в приложении.',
          accent: 'АКТИВНЫХ ЗАКАЗОВ: ${orders.length.toString().padLeft(2, '0')}',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: 'Предзаказы',
                value: preorderCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                label: 'В пути',
                value: activeOrder == null ? '0' : '1',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeOrder == null)
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('АКТИВНЫЙ ЗАКАЗ', style: AppTypography.eyebrow),
                const SizedBox(height: 12),
                Text(
                  'Пока нет оформленных заказов',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Откройте каталог, выберите изделие и пройдите шаги оформления.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          _orderCard(
            order: activeOrder,
            cta: 'ОТСЛЕДИТЬ',
            onTap: () {
              setState(() {
                _latestOrderId = activeOrder.id;
                _view = ClientView.tracking;
              });
            },
          ),
        const SizedBox(height: 12),
        _sectionLabel('БЫСТРЫЙ ВЫБОР'),
        const SizedBox(height: 12),
        ...catalog.take(2).map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _productCard(
              product: product,
              onTap: () => _openProduct(product),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('КОЛЛЕКЦИИ'),
        const SizedBox(height: 12),
        ...archiveCollections.map(
          (collection) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _surfaceCard(
              onTap: () => _openProduct(catalog.first),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${collection.year} / ${collection.season}',
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          collection.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    collection.released ? 'АКТИВНАЯ' : 'АРХИВ',
                    style: AppTypography.code,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ...catalog.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _productCard(
              product: product,
              onTap: () => _openProduct(product),
            ),
          ),
        ),
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
          _surfaceCard(
            child: Text(
              'История появится после первого оформленного заказа.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(
              order: order,
              cta: 'ДЕТАЛИ',
              onTap: () {
                setState(() {
                  _latestOrderId = order.id;
                  _view = ClientView.tracking;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileScreen(
    List<OrderModel> orders,
    UserRole currentRole,
    OrderModel? trackedOrder,
  ) {
    final user = ref.watch(currentUserProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('КЛИЕНТСКИЙ ПРОФИЛЬ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              Text(
                user?.displayName.toUpperCase() ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border.all(color: AppColors.black),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'РОЛЬ: ${roleLabel(currentRole)}',
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ПРОГРАММА ЛОЯЛЬНОСТИ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: ((orders.length % 4) + 1) / 4),
              const SizedBox(height: 10),
              Text(
                'ЗАКАЗОВ: ${orders.length} / СЛЕДУЮЩИЙ УРОВЕНЬ: ПРИОРИТЕТ',
                style: AppTypography.code,
              ),
            ],
          ),
        ),
        if (trackedOrder != null) ...[
          const SizedBox(height: 12),
          _orderCard(
            order: trackedOrder,
            cta: 'ОТСЛЕДИТЬ',
            onTap: () => setState(() => _view = ClientView.tracking),
          ),
        ],
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

  Widget _buildProductScreen() {
    final product = _selectedProduct!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          color: AppColors.surfaceHigh,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.preorder ? 'ПРЕДЗАКАЗ' : 'В НАЛИЧИИ',
                style: AppTypography.eyebrow,
              ),
              const Spacer(),
              Text(
                product.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: 'ИНФОРМАЦИЯ ОБ ИЗДЕЛИИ',
          rows: [
            OrderInfoRowData(label: 'Артикул', value: product.sku),
            OrderInfoRowData(label: 'Материал', value: product.material),
            OrderInfoRowData(label: 'Размер', value: product.sizeLabel),
            OrderInfoRowData(label: 'Стоимость', value: formatCurrency(product.price)),
          ],
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Text(
            product.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (product.preorder) ...[
          const SizedBox(height: 12),
          _sectionLabel('ДАТА ГОТОВНОСТИ'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dateOptions
                .map(
                  (date) => ChoiceChip(
                    label: Text(
                      '${monthShort(date.month)} ${date.day.toString().padLeft(2, '0')}',
                    ),
                    selected: _selectedDate == date,
                    onSelected: (_) => setState(() => _selectedDate = date),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        AvishuButton(
          text: product.preorder ? 'ПРОДОЛЖИТЬ ПРЕДЗАКАЗ' : 'ОФОРМИТЬ ЗАКАЗ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () {
            setState(() {
              _view = ClientView.checkout;
              _deliveryMethod = DeliveryMethod.courier;
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
        OrderInfoCard(
          title: 'СОСТАВ ЗАКАЗА',
          rows: [
            OrderInfoRowData(label: 'Изделие', value: product.title),
            OrderInfoRowData(label: 'Размер', value: product.sizeLabel),
            OrderInfoRowData(label: 'Стоимость', value: formatCurrency(product.price)),
          ],
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            children: [
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Город'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apartmentController,
                decoration: const InputDecoration(labelText: 'Квартира / офис'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий к заказу',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionLabel('СПОСОБ ПОЛУЧЕНИЯ'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _deliveryCard(
                label: DeliveryMethod.courier.label,
                active: _deliveryMethod == DeliveryMethod.courier,
                onTap: () => setState(
                  () => _deliveryMethod = DeliveryMethod.courier,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _deliveryCard(
                label: DeliveryMethod.pickup.label,
                active: _deliveryMethod == DeliveryMethod.pickup,
                onTap: () => setState(
                  () => _deliveryMethod = DeliveryMethod.pickup,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: 'ИТОГО',
          rows: _checkoutRows(product),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: 'ПЕРЕЙТИ К ОПЛАТЕ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () {
            if (_validateCheckoutFields()) {
              setState(() => _view = ClientView.payment);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPaymentScreen(String clientId) {
    final product = _selectedProduct!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ОПЛАТА КАРТОЙ', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              TextField(
                controller: _cardController,
                decoration: const InputDecoration(labelText: 'Номер карты'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      decoration: const InputDecoration(labelText: 'MM / YY'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvController,
                      decoration: const InputDecoration(labelText: 'CVV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: 'ДЕТАЛИ ОПЛАТЫ',
          rows: _checkoutRows(product),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: 'ОПЛАТИТЬ',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: () => _submitOrder(clientId),
        ),
      ],
    );
  }

  Widget _buildTrackingScreen(OrderModel? order) {
    if (order == null) {
      return _surfaceCard(
        child: Text(
          'Ожидаем синхронизацию заказа.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Text(
                'СТАТУС / ${order.status.clientLabel}',
                style: AppTypography.code,
              ),
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
            rows: [OrderInfoRowData(label: 'Комментарий', value: order.clientNote)],
          ),
        ],
        if (order.franchiseeNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: 'ПОМЕТКА ФРАНЧАЙЗИ',
            rows: [
              OrderInfoRowData(label: 'Статус', value: order.franchiseeNote),
            ],
          ),
        ],
        if (order.productionNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: 'ПОМЕТКА ПРОИЗВОДСТВА',
            rows: [
              OrderInfoRowData(label: 'Производство', value: order.productionNote),
            ],
          ),
        ],
        const SizedBox(height: 12),
        OrderTimelineCard(timeline: order.timeline),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AvishuButton(
                text: 'НАЗАД',
                onPressed: () {
                  setState(() {
                    _tab = ClientTab.dashboard;
                    _view = ClientView.root;
                  });
                },
                variant: AvishuButtonVariant.ghost,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AvishuButton(
                text: 'КОЛЛЕКЦИИ',
                onPressed: () {
                  setState(() {
                    _tab = ClientTab.collections;
                    _view = ClientView.root;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitOrder(String clientId) async {
    final product = _selectedProduct!;
    if (!_validateCheckoutFields() || !_validatePaymentFields()) {
      return;
    }

    final orderId = await ref.read(orderRepositoryProvider).createOrder(
      clientId: clientId,
      productName: product.title,
      sizeLabel: product.sizeLabel,
      amount: _totalPrice(product),
      isPreorder: product.preorder,
      readyBy: product.preorder ? _selectedDate : null,
      deliveryMethod: _deliveryMethod,
      deliveryCity: _cityController.text.trim(),
      deliveryAddress: _addressController.text.trim(),
      apartment: _apartmentController.text.trim(),
      paymentLast4: _cardLast4,
      clientNote: _noteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _latestOrderId = orderId;
      _tab = ClientTab.dashboard;
      _view = ClientView.tracking;
    });
  }

  bool _validateCheckoutFields() {
    if (_cityController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      _showMessage('Заполните город и адрес доставки.');
      return false;
    }
    return true;
  }

  bool _validatePaymentFields() {
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4 ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().length < 3) {
      _showMessage('Проверьте данные банковской карты.');
      return false;
    }
    return true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openProduct(CatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _selectedDate = product.preorder ? dateOptions[1] : null;
      _view = ClientView.product;
    });
  }

  String get _cardLast4 {
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  double _totalPrice(CatalogProduct product) {
    return product.price + _deliveryMethod.fee;
  }

  List<OrderInfoRowData> _checkoutRows(CatalogProduct product) {
    return [
      OrderInfoRowData(label: 'Изделие', value: product.title),
      OrderInfoRowData(label: 'Размер', value: product.sizeLabel),
      OrderInfoRowData(label: 'Стоимость', value: formatCurrency(product.price)),
      OrderInfoRowData(
        label: 'Доставка',
        value: '${_deliveryMethod.label} / ${formatCurrency(_deliveryMethod.fee)}',
      ),
      if (product.preorder && _selectedDate != null)
        OrderInfoRowData(
          label: 'Дата готовности',
          value: formatDate(_selectedDate!),
        ),
      OrderInfoRowData(
        label: 'Итого',
        value: formatCurrency(_totalPrice(product)),
      ),
    ];
  }

  Widget _heroCard({
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

  Widget _metricCard({required String label, required String value}) {
    return _surfaceCard(
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

  Widget _productCard({
    required CatalogProduct product,
    required VoidCallback onTap,
  }) {
    return _surfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 76,
            height: 104,
            color: product.preorder ? AppColors.surfaceHigh : AppColors.surfaceLow,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  product.material,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.preorder ? 'ПРЕДЗАКАЗ' : 'В НАЛИЧИИ'} / ${product.sizeLabel}',
                  style: AppTypography.code,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatCurrency(product.price),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _orderCard({
    required OrderModel order,
    required String cta,
    required VoidCallback onTap,
  }) {
    return _surfaceCard(
      onTap: onTap,
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
          const SizedBox(height: 10),
          Text(
            order.productName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${order.sizeLabel} / ${formatCurrency(order.amount)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text(cta, style: AppTypography.button),
        ],
      ),
    );
  }

  Widget _deliveryCard({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
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
            Text(
              'СПОСОБ',
              style: AppTypography.eyebrow.copyWith(
                color: active ? AppColors.surfaceDim : AppColors.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: active ? AppColors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surfaceCard({
    required Widget child,
    VoidCallback? onTap,
  }) {
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

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTypography.eyebrow.copyWith(letterSpacing: 3),
    );
  }
}
