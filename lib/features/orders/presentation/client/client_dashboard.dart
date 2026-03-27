import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../shared/widgets/role_switch_sheet.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/delivery_method.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../products/data/product_repository.dart';
import '../shared/order_formatters.dart';
import '../shared/order_panels.dart';
import 'client_data.dart';

enum CatalogSortOption {
  defaultOrder,
  newFirst,
  priceLowToHigh,
  priceHighToLow,
}

extension CatalogSortOptionX on CatalogSortOption {
  String get label {
    switch (this) {
      case CatalogSortOption.defaultOrder:
        return 'По умолчанию';
      case CatalogSortOption.newFirst:
        return 'Сначала новинки';
      case CatalogSortOption.priceLowToHigh:
        return 'Цена: по возрастанию';
      case CatalogSortOption.priceHighToLow:
        return 'Цена: по убыванию';
    }
  }
}

final clientOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  clientId,
) {
  return ref.watch(orderRepositoryProvider).clientOrders(clientId);
});

final catalogProductsProvider = StreamProvider<List<CatalogProduct>>((ref) {
  return ref
      .watch(productRepositoryProvider)
      .watchActiveProducts()
      .map(catalogFromProducts);
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
  String _activeSection = catalogSections.first;
  String? _categoryFilter;
  String? _sizeFilter;
  String? _colorFilter;
  late RangeValues _priceRange;
  CatalogSortOption _sortOption = CatalogSortOption.defaultOrder;
  String? _selectedColor;
  String? _selectedSize;
  int _selectedImageIndex = 0;
  int _quantity = 1;
  bool _descriptionExpanded = true;
  bool _specificationsExpanded = false;
  bool _careExpanded = false;
  List<CatalogProduct> _catalogProducts = catalog;

  final Set<String> _favoriteProductIds = <String>{};
  final _cityController = TextEditingController(text: 'Алматы');
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController(text: '01 / 28');
  final _cvvController = TextEditingController();
  final _noteController = TextEditingController();

  static const _navItems = [
    AvishuNavItem(label: 'ПАНЕЛЬ', icon: Icons.grid_view_rounded),
    AvishuNavItem(label: 'КАТАЛОГ', icon: Icons.layers_outlined),
    AvishuNavItem(label: 'ИСТОРИЯ', icon: Icons.inventory_2_outlined),
    AvishuNavItem(label: 'ПРОФИЛЬ', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(_catalogMinPrice, _catalogMaxPrice);
  }

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

  double get _catalogMinPrice => _catalogProducts
      .map((product) => product.price)
      .reduce((a, b) => a < b ? a : b);

  double get _catalogMaxPrice => _catalogProducts
      .map((product) => product.price)
      .reduce((a, b) => a > b ? a : b);

  List<CatalogProduct> get _sectionProducts => _catalogProducts
      .where((product) => product.sections.contains(_activeSection))
      .toList();

  List<String> get _categoryOptions =>
      _sortedDistinct(_sectionProducts.map((product) => product.category));

  List<String> get _sizeOptions =>
      _sortedDistinct(_sectionProducts.expand((product) => product.sizes));

  List<String> get _colorOptions =>
      _sortedDistinct(_sectionProducts.expand((product) => product.colors));

  List<CatalogProduct> get _visibleProducts {
    final filtered = _sectionProducts.where((product) {
      final categoryMatches =
          _categoryFilter == null || product.category == _categoryFilter;
      final sizeMatches =
          _sizeFilter == null || product.sizes.contains(_sizeFilter);
      final colorMatches =
          _colorFilter == null || product.colors.contains(_colorFilter);
      final priceMatches =
          product.price >= _priceRange.start &&
          product.price <= _priceRange.end;
      return categoryMatches && sizeMatches && colorMatches && priceMatches;
    }).toList();

    switch (_sortOption) {
      case CatalogSortOption.defaultOrder:
        return filtered;
      case CatalogSortOption.newFirst:
        filtered.sort((a, b) {
          final newPriority = (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0);
          if (newPriority != 0) {
            return newPriority;
          }
          return a.price.compareTo(b.price);
        });
        return filtered;
      case CatalogSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        return filtered;
      case CatalogSortOption.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final catalogProducts = ref
        .watch(catalogProductsProvider)
        .maybeWhen(
          data: (products) => products.isEmpty ? catalog : products,
          orElse: () => catalog,
        );
    _applyCatalogSource(catalogProducts);

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
          if (_tab == ClientTab.collections) {
            _showCatalogMenuSheet();
          } else {
            showAppSettingsSheet(context);
          }
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
        if (_selectedProduct == null) {
          return 'КЛИЕНТ / ТОВАР';
        }
        return 'КЛИЕНТ / ${_selectedProduct!.category.toUpperCase()}';
      case ClientView.checkout:
        return 'КЛИЕНТ / ОФОРМЛЕНИЕ';
      case ClientView.payment:
        return 'КЛИЕНТ / ОПЛАТА';
      case ClientView.tracking:
        return 'КЛИЕНТ / ТРЕКИНГ';
      case ClientView.root:
        switch (_tab) {
          case ClientTab.dashboard:
            return 'КЛИЕНТ / ПАНЕЛЬ';
          case ClientTab.collections:
            return 'КЛИЕНТ / КАТАЛОГ';
          case ClientTab.archive:
            return 'КЛИЕНТ / ИСТОРИЯ';
          case ClientTab.profile:
            return 'КЛИЕНТ / ПРОФИЛЬ';
        }
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
      ClientTab.profile => _buildProfileScreen(
        orders,
        currentRole,
        trackedOrder,
      ),
    };
  }

  Widget _buildDashboardScreen(List<OrderModel> orders) {
    final activeOrder = resolveTrackedOrder(orders, _latestOrderId);
    final preorderCount = orders.where((order) => order.isPreorder).length;
    final featuredProducts = _catalogProducts
        .where((product) => product.isNew)
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          title: 'КАПСУЛА СЕЗОНА',
          subtitle:
              'Каталог теперь собран с разделами, фильтрами, сортировкой и полноценной карточкой товара в фирменном AVISHU-ритме.',
          accent:
              'НОВЫХ МОДЕЛЕЙ: ${_catalogProducts.where((item) => item.isNew).length}',
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
                label: 'Любимые',
                value: _favoriteProductIds.length.toString(),
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
                  'Заказов пока нет',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Откройте каталог, настройте выдачу как на сайте и оформите первый заказ в одном потоке.',
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
        ...featuredProducts.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _productCard(
              product: product,
              onTap: () => _openProduct(product),
            ),
          ),
        ),
        _surfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Перейти в каталог',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AvishuButton(
                text: 'ОТКРЫТЬ',
                onPressed: () {
                  setState(() {
                    _tab = ClientTab.collections;
                    _view = ClientView.root;
                    _selectSection('Новинки');
                  });
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsScreen() {
    final products = _visibleProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ГЛАВНАЯ / ${_activeSection.toUpperCase()}',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('РАЗДЕЛЫ КАТАЛОГА', style: AppTypography.eyebrow),
              const SizedBox(height: 12),
              ...catalogSections.map(
                (section) => _catalogSectionTile(
                  label: section,
                  active: section == _activeSection,
                  onTap: () {
                    setState(() => _selectSection(section));
                  },
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeSection.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Фильтрация и сортировка собраны по логике сайта, но в более жестком и чистом мобильном интерфейсе AVISHU.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${products.length} моделей', style: AppTypography.code),
                ],
              ),
              const SizedBox(height: 16),
              _sortSelector(),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  setState(_resetCatalogFilters);
                },
                child: Text(
                  'Очистить выбор',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _filterGroup(
                title: 'Категория',
                options: _categoryOptions,
                selectedValue: _categoryFilter,
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              _filterGroup(
                title: 'Размер',
                options: _sizeOptions,
                selectedValue: _sizeFilter,
                onChanged: (value) => setState(() => _sizeFilter = value),
              ),
              _filterGroup(
                title: 'Цвет',
                options: _colorOptions,
                selectedValue: _colorFilter,
                onChanged: (value) => setState(() => _colorFilter = value),
              ),
              Text('ЦЕНА', style: AppTypography.eyebrow),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.black,
                  inactiveTrackColor: AppColors.surfaceDim,
                  thumbColor: AppColors.black,
                  overlayColor: AppColors.black.withValues(alpha: 0.08),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: RangeSlider(
                  min: _catalogMinPrice,
                  max: _catalogMaxPrice,
                  divisions: 10,
                  values: _priceRange,
                  onChanged: (values) {
                    setState(() => _priceRange = values);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatCurrency(_priceRange.start)),
                  Text(formatCurrency(_priceRange.end)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('НЕТ СОВПАДЕНИЙ', style: AppTypography.eyebrow),
                const SizedBox(height: 10),
                Text(
                  'Попробуйте снять один из фильтров или выбрать другой раздел каталога.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ...products.map(
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.outline),
              ),
              const SizedBox(height: 14),
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
        const SizedBox(height: 12),
        _surfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Любимые модели',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _favoriteProductIds.length.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.titleLarge,
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
    final selectedColor = _selectedColor ?? product.defaultColor;
    final selectedSize = _selectedSize ?? product.defaultSize;
    final isFavorite = _favoriteProductIds.contains(product.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ГЛАВНАЯ / ${product.season.toUpperCase()} / ${product.category.toUpperCase()} / ${product.title}',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productGallery(product),
              const SizedBox(height: 16),
              Text(
                product.category.toUpperCase(),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                formatCurrency(product.price),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                product.shortDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaChip(product.availabilityLabel),
                  _metaChip(product.material),
                  _metaChip(product.silhouette.toUpperCase()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: 'ИНФОРМАЦИЯ О ТОВАРЕ',
          rows: [
            OrderInfoRowData(label: 'Артикул', value: product.sku),
            OrderInfoRowData(label: 'Материал', value: product.material),
            OrderInfoRowData(label: 'Силуэт', value: product.silhouette),
            OrderInfoRowData(label: 'Цвет', value: selectedColor),
            OrderInfoRowData(label: 'Размер', value: selectedSize),
          ],
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ЦВЕТ', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.colors
                    .map(
                      (color) => _selectionPill(
                        label: color,
                        selected: selectedColor == color,
                        onTap: () => setState(() => _selectedColor = color),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text('РАЗМЕР', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.sizes
                    .map(
                      (size) => _selectionPill(
                        label: size,
                        selected: selectedSize == size,
                        onTap: () => setState(() => _selectedSize = size),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _showSizeGuideSheet,
                child: Row(
                  children: [
                    const Icon(Icons.straighten, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Размерная сетка',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (product.preorder) ...[
                const SizedBox(height: 16),
                Text('ДАТА ГОТОВНОСТИ', style: AppTypography.eyebrow),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dateOptions
                      .map(
                        (date) => _selectionPill(
                          label:
                              '${monthShort(date.month)} ${date.day.toString().padLeft(2, '0')}',
                          selected: _selectedDate == date,
                          onTap: () => setState(() => _selectedDate = date),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                product.inStock ? 'В наличии' : 'Нет в наличии',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: product.inStock ? AppColors.black : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.atelierNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _quantitySelector()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AvishuButton(
                      text: isFavorite ? 'В ИЗБРАННОМ' : 'В ИЗБРАННОЕ',
                      expanded: true,
                      variant: AvishuButtonVariant.outline,
                      icon: isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border_outlined,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      onPressed: () {
                        setState(() => _toggleFavorite(product.id));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AvishuButton(
                text: product.preorder
                    ? 'ПРОДОЛЖИТЬ ПРЕДЗАКАЗ'
                    : 'ОФОРМИТЬ ЗАКАЗ',
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
          ),
        ),
        const SizedBox(height: 12),
        _productAccordion(
          title: 'ОПИСАНИЕ',
          expanded: _descriptionExpanded,
          onToggle: () {
            setState(() => _descriptionExpanded = !_descriptionExpanded);
          },
          child: Text(
            product.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        _productAccordion(
          title: 'ХАРАКТЕРИСТИКИ',
          expanded: _specificationsExpanded,
          onToggle: () {
            setState(() => _specificationsExpanded = !_specificationsExpanded);
          },
          child: Column(
            children: product.specifications
                .map(
                  (spec) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            spec.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            spec.value,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _productAccordion(
          title: 'УХОД',
          expanded: _careExpanded,
          onToggle: () {
            setState(() => _careExpanded = !_careExpanded);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: product.care
                .map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $rule',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
                .toList(),
          ),
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
            OrderInfoRowData(
              label: 'Цвет',
              value: _selectedColor ?? product.defaultColor,
            ),
            OrderInfoRowData(
              label: 'Размер',
              value: _selectedSize ?? product.defaultSize,
            ),
            OrderInfoRowData(label: 'Количество', value: '$_quantity'),
            OrderInfoRowData(
              label: 'Стоимость позиции',
              value: formatCurrency(product.price),
            ),
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
                onTap: () =>
                    setState(() => _deliveryMethod = DeliveryMethod.courier),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _deliveryCard(
                label: DeliveryMethod.pickup.label,
                active: _deliveryMethod == DeliveryMethod.pickup,
                onTap: () =>
                    setState(() => _deliveryMethod = DeliveryMethod.pickup),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OrderInfoCard(title: 'ИТОГО', rows: _checkoutRows(product)),
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
        OrderInfoCard(title: 'ДЕТАЛИ ОПЛАТЫ', rows: _checkoutRows(product)),
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
            rows: [
              OrderInfoRowData(label: 'Комментарий', value: order.clientNote),
            ],
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
              OrderInfoRowData(
                label: 'Производство',
                value: order.productionNote,
              ),
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
                text: 'КАТАЛОГ',
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

    final orderId = await ref
        .read(orderRepositoryProvider)
        .createOrder(
          clientId: clientId,
          productId: product.id,
          productName:
              '${product.title} / ${_selectedColor ?? product.defaultColor}',
          sizeLabel: _selectedSize ?? product.defaultSize,
          quantity: _quantity,
          unitPrice: product.price,
          imageUrl: product.imageUrls.first,
          currency: 'KZT',
          amount: _totalPrice(product),
          isPreorder: product.preorder,
          readyBy: product.preorder ? _selectedDate : null,
          deliveryMethod: _deliveryMethod,
          deliveryCity: _cityController.text.trim(),
          deliveryAddress: _addressController.text.trim(),
          apartment: _apartmentController.text.trim(),
          paymentLast4: _cardLast4,
          clientNote: _composeOrderNote(product),
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

  void _applyCatalogSource(List<CatalogProduct> products) {
    if (products.isEmpty) {
      return;
    }

    _catalogProducts = products;

    final minPrice = _catalogMinPrice;
    final maxPrice = _catalogMaxPrice;
    if (_priceRange.start < minPrice ||
        _priceRange.end > maxPrice ||
        _priceRange.start > _priceRange.end) {
      _priceRange = RangeValues(minPrice, maxPrice);
    }

    if (_selectedProduct != null) {
      for (final product in _catalogProducts) {
        if (product.id == _selectedProduct!.id) {
          _selectedProduct = product;
          break;
        }
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProduct(CatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _selectedDate = product.preorder ? dateOptions[1] : null;
      _selectedColor = product.defaultColor;
      _selectedSize = product.defaultSize;
      _selectedImageIndex = 0;
      _quantity = 1;
      _descriptionExpanded = true;
      _specificationsExpanded = false;
      _careExpanded = false;
      _view = ClientView.product;
    });
  }

  void _toggleFavorite(String productId) {
    if (_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.remove(productId);
      return;
    }
    _favoriteProductIds.add(productId);
  }

  void _selectSection(String section) {
    _activeSection = section;
    _resetCatalogFilters();
  }

  void _resetCatalogFilters() {
    _categoryFilter = null;
    _sizeFilter = null;
    _colorFilter = null;
    _sortOption = CatalogSortOption.defaultOrder;
    _priceRange = RangeValues(_catalogMinPrice, _catalogMaxPrice);
  }

  String get _cardLast4 {
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  double _totalPrice(CatalogProduct product) {
    return product.price * _quantity + _deliveryMethod.fee;
  }

  String _composeOrderNote(CatalogProduct product) {
    final customerNote = _noteController.text.trim();
    final lines = <String>[
      'Цвет: ${_selectedColor ?? product.defaultColor}',
      'Количество: $_quantity',
      if (customerNote.isNotEmpty) 'Комментарий клиента: $customerNote',
    ];
    return lines.join('\n');
  }

  List<OrderInfoRowData> _checkoutRows(CatalogProduct product) {
    return [
      OrderInfoRowData(label: 'Изделие', value: product.title),
      OrderInfoRowData(
        label: 'Цвет',
        value: _selectedColor ?? product.defaultColor,
      ),
      OrderInfoRowData(
        label: 'Размер',
        value: _selectedSize ?? product.defaultSize,
      ),
      OrderInfoRowData(label: 'Количество', value: '$_quantity'),
      OrderInfoRowData(
        label: 'Стоимость',
        value: formatCurrency(product.price * _quantity),
      ),
      OrderInfoRowData(
        label: 'Доставка',
        value:
            '${_deliveryMethod.label} / ${formatCurrency(_deliveryMethod.fee)}',
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

  Widget _catalogSectionTile({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.black : AppColors.outlineVariant,
            ),
          ),
          color: active ? AppColors.surfaceLow : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: active
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Icon(
              active ? Icons.arrow_outward : Icons.arrow_right_alt,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortSelector() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.black),
      ),
      child: PopupMenuButton<CatalogSortOption>(
        onSelected: (value) {
          setState(() => _sortOption = value);
        },
        itemBuilder: (context) => CatalogSortOption.values
            .map(
              (option) => PopupMenuItem<CatalogSortOption>(
                value: option,
                child: Text(option.label),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'СОРТИРОВАТЬ: ${_sortOption.label.toUpperCase()}',
                  style: AppTypography.button.copyWith(letterSpacing: 2.2),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterGroup({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _selectionPill(
                label: 'Все',
                selected: selectedValue == null,
                onTap: () => onChanged(null),
              ),
              ...options.map(
                (option) => _selectionPill(
                  label: option,
                  selected: selectedValue == option,
                  onTap: () => onChanged(option),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectionPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: selected ? AppColors.white : AppColors.black,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(label.toUpperCase(), style: AppTypography.code),
    );
  }

  Widget _productGallery(CatalogProduct product) {
    final imageUrl = product.imageUrls[_selectedImageIndex];
    final isFavorite = _favoriteProductIds.contains(product.id);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.8,
          child: Stack(
            children: [
              Positioned.fill(child: _networkProductImage(imageUrl)),
              Positioned(top: 12, left: 12, child: _metaChip(product.season)),
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: () {
                    setState(() => _toggleFavorite(product.id));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceLowest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border_outlined,
                      size: 20,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: product.imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = index == _selectedImageIndex;
              return InkWell(
                onTap: () => setState(() => _selectedImageIndex = index),
                child: Container(
                  width: 74,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? AppColors.black
                          : AppColors.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: _networkProductImage(
                    product.imageUrls[index],
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _productAccordion({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTypography.button)),
                  Icon(expanded ? Icons.remove : Icons.add),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _quantitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.black),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            _quantity.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: () => setState(() => _quantity++),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _productCard({
    required CatalogProduct product,
    required VoidCallback onTap,
  }) {
    final isFavorite = _favoriteProductIds.contains(product.id);

    return _surfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.78,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _networkProductImage(
                    product.imageUrls.first,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _metaChip(product.category),
                ),
                if (product.isNew)
                  Positioned(top: 12, right: 12, child: _metaChip('Новинка')),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: InkWell(
                    onTap: () {
                      setState(() => _toggleFavorite(product.id));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLowest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.material} / ${product.silhouette}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
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
          const SizedBox(height: 10),
          Text(
            product.shortDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(product.availabilityLabel),
              _metaChip(product.defaultSize),
              _metaChip('${product.colors.length} цвета'),
            ],
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

  Widget _sectionLabel(String label) {
    return Text(label, style: AppTypography.eyebrow.copyWith(letterSpacing: 3));
  }

  Widget _networkProductImage(String url, {BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return Container(
          color: AppColors.surfaceHigh,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.surfaceHigh,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.grey,
            ),
          ),
        );
      },
    );
  }

  List<String> _sortedDistinct(Iterable<String> values) {
    final result = values.toSet().toList()..sort();
    return result;
  }

  Future<void> _showCatalogMenuSheet() {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'catalog-menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 72),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 430,
                  maxHeight: screenHeight * 0.72,
                ),
                child: Material(
                  color: AppColors.surfaceLowest,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('РАЗДЕЛЫ КАТАЛОГА', style: AppTypography.eyebrow),
                        const SizedBox(height: 8),
                        Text(
                          'Быстрый переход по коллекциям в мобильной адаптации.',
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ...catalogSections.map(
                          (section) => _catalogSectionTile(
                            label: section,
                            active: section == _activeSection,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              setState(() => _selectSection(section));
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        AvishuButton(
                          text: 'НАСТРОЙКИ',
                          expanded: true,
                          variant: AvishuButtonVariant.outline,
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            showAppSettingsSheet(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation =
            Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
    );
  }

  void _showSizeGuideSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLowest,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'РАЗМЕРНАЯ СЕТКА',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _sizeGuideTable(baseSizeGuide),
                        const SizedBox(height: 20),
                        _sizeGuideTable(plusSizeGuide),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sizeGuideTable(SizeGuideGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(group.unitLabel.toUpperCase(), style: AppTypography.code),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.outlineVariant),
                ),
                children: [
                  TableRow(
                    children: [
                      _tableHeaderCell(''),
                      ...group.columns.map(
                        (column) => _tableHeaderCell(column.size),
                      ),
                    ],
                  ),
                  _measurementRow(
                    'Обхват груди',
                    group.columns.map((column) => column.chest).toList(),
                  ),
                  _measurementRow(
                    'Обхват талии',
                    group.columns.map((column) => column.waist).toList(),
                  ),
                  _measurementRow(
                    'Обхват бедер',
                    group.columns.map((column) => column.hips).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _measurementRow(String label, List<String> values) {
    return TableRow(
      children: [
        _tableBodyCell(label, alignStart: true),
        ...values.map((value) => _tableBodyCell(value)),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.button.copyWith(letterSpacing: 1.4),
      ),
    );
  }

  Widget _tableBodyCell(String text, {bool alignStart = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: alignStart ? TextAlign.left : TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
