import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../../shared/widgets/avishu_order_tracker.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/delivery_method.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../products/data/product_repository.dart';
import '../shared/order_digital_twin_card.dart';
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
  String labelFor(AppLanguage language) {
    switch (this) {
      case CatalogSortOption.defaultOrder:
        return tr(language, ru: 'По умолчанию', en: 'Default');
      case CatalogSortOption.newFirst:
        return tr(language, ru: 'Сначала новинки', en: 'New First');
      case CatalogSortOption.priceLowToHigh:
        return tr(
          language,
          ru: 'Цена: по возрастанию',
          en: 'Price: Low to High',
        );
      case CatalogSortOption.priceHighToLow:
        return tr(language, ru: 'Цена: по убыванию', en: 'Price: High to Low');
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
  bool _catalogSectionsExpanded = false;
  bool _catalogFiltersExpanded = false;
  bool _descriptionExpanded = true;
  bool _specificationsExpanded = false;
  bool _careExpanded = false;
  bool _showFavoritesOnly = false;
  bool _isSubmitting = false;
  bool _hasStatusBadge = false;
  OrderStatus? _lastKnownOrderStatus;
  List<CatalogProduct> _catalogProducts = catalog;

  final Set<String> _favoriteProductIds = <String>{};
  final _cityController = TextEditingController(text: 'Алматы');
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController(text: '01 / 28');
  final _cvvController = TextEditingController();
  final _noteController = TextEditingController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(_catalogMinPrice, _catalogMaxPrice);
    _pageController = PageController();
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
    _pageController.dispose();
    super.dispose();
  }

  double get _catalogMinPrice => _catalogProducts
      .map((product) => product.price)
      .reduce((a, b) => a < b ? a : b);

  double get _catalogMaxPrice => _catalogProducts
      .map((product) => product.price)
      .reduce((a, b) => a > b ? a : b);

  AppLanguage get _language => ref.read(appSettingsProvider).language;

  CatalogCardSize get _catalogCardSize =>
      ref.read(appSettingsProvider).catalogCardSize;

  String _t({required String ru, required String en}) {
    return tr(_language, ru: ru, en: en);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(ru: 'ПАНЕЛЬ', en: 'HOME'),
      icon: Icons.grid_view_rounded,
    ),
    AvishuNavItem(
      label: _t(ru: 'КАТАЛОГ', en: 'CATALOG'),
      icon: Icons.layers_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ИСТОРИЯ', en: 'ORDERS'),
      icon: Icons.inventory_2_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ПРОФИЛЬ', en: 'PROFILE'),
      icon: Icons.person_outline,
      badge: _hasStatusBadge,
    ),
  ];

  List<CatalogProduct> get _sectionProducts => _catalogProducts
      .where((product) => product.sections.contains(_activeSection))
      .toList();

  List<CatalogProduct> get _favoriteProducts => _catalogProducts
      .where((product) => _favoriteProductIds.contains(product.id))
      .toList();

  List<String> get _categoryOptions =>
      _sortedDistinct(_sectionProducts.map((product) => product.category));

  List<String> get _sizeOptions =>
      _sortedDistinct(_sectionProducts.expand((product) => product.sizes));

  List<String> get _colorOptions =>
      _sortedDistinct(_sectionProducts.expand((product) => product.colors));

  List<CatalogProduct> get _visibleProducts {
    final source = _showFavoritesOnly ? _favoriteProducts : _sectionProducts;

    final filtered = source.where((product) {
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

  int get _activeCatalogFiltersCount {
    var count = 0;
    if (_categoryFilter != null) {
      count++;
    }
    if (_sizeFilter != null) {
      count++;
    }
    if (_colorFilter != null) {
      count++;
    }
    if (_sortOption != CatalogSortOption.defaultOrder) {
      count++;
    }
    if (_showFavoritesOnly) {
      count++;
    }
    if (_priceRange.start != _catalogMinPrice ||
        _priceRange.end != _catalogMaxPrice) {
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
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
      actionIcon: null,
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
      onActionTap: null,
      onNavSelected: (index) {
        setState(() {
          _tab = ClientTab.values[index];
          _view = ClientView.root;
          if (_tab == ClientTab.profile) _hasStatusBadge = false;
        });
      },
      body: ordersAsync.when(
        data: (orders) {
          // Track status changes and show badge on Profile tab
          final tracked = resolveTrackedOrder(orders, _latestOrderId);
          if (tracked != null) {
            final status = tracked.status;
            if (_lastKnownOrderStatus != null &&
                _lastKnownOrderStatus != status &&
                _tab != ClientTab.profile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _hasStatusBadge = true);
              });
            }
            if (_lastKnownOrderStatus != status) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _lastKnownOrderStatus = status);
              });
            }
          }
          return SingleChildScrollView(
            key: PageStorageKey('client-$_tab-$_view'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: _buildScreen(
              context,
              orders,
              user.uid,
              user.role,
              trackedOrder,
            ),
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

  String get _metaLabel {
    switch (_view) {
      case ClientView.product:
        if (_selectedProduct == null) {
          return _t(ru: 'КЛИЕНТ / ТОВАР', en: 'CLIENT / PRODUCT');
        }
        return '${_t(ru: 'КЛИЕНТ', en: 'CLIENT')} / '
            '${localizeCatalogSection(_language, _selectedProduct!.category).toUpperCase()}';
      case ClientView.checkout:
        return _t(ru: 'КЛИЕНТ / ОФОРМЛЕНИЕ', en: 'CLIENT / CHECKOUT');
      case ClientView.payment:
        return _t(ru: 'КЛИЕНТ / ОПЛАТА', en: 'CLIENT / PAYMENT');
      case ClientView.tracking:
        return _t(ru: 'КЛИЕНТ / ТРЕКИНГ', en: 'CLIENT / TRACKING');
      case ClientView.root:
        switch (_tab) {
          case ClientTab.dashboard:
            return _t(ru: 'КЛИЕНТ / ПАНЕЛЬ', en: 'CLIENT / HOME');
          case ClientTab.collections:
            return _t(ru: 'КЛИЕНТ / КАТАЛОГ', en: 'CLIENT / CATALOG');
          case ClientTab.archive:
            return _t(ru: 'КЛИЕНТ / ИСТОРИЯ', en: 'CLIENT / ORDERS');
          case ClientTab.profile:
            return _t(ru: 'КЛИЕНТ / ПРОФИЛЬ', en: 'CLIENT / PROFILE');
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
      return _buildTrackingScreen(
        trackedOrder,
        clientDisplayName: ref.watch(currentUserProvider).value?.name,
      );
    }

    return switch (_tab) {
      ClientTab.dashboard => _buildDashboardScreen(orders),
      ClientTab.collections => _buildCompactCollectionsScreen(),
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
          title: _t(ru: 'КАПСУЛА СЕЗОНА', en: 'SEASON CAPSULE'),
          subtitle: _t(
            ru: 'Каталог собран с разделами, фильтрами, сортировкой и полноценной карточкой товара в фирменном AVISHU-ритме.',
            en: 'The catalog now combines sections, filters, sorting, and a full product card in the AVISHU rhythm.',
          ),
          accent: _t(
            ru: 'НОВЫХ МОДЕЛЕЙ: ${_catalogProducts.where((item) => item.isNew).length}',
            en: 'NEW MODELS: ${_catalogProducts.where((item) => item.isNew).length}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: _t(ru: 'Предзаказы', en: 'Preorders'),
                value: preorderCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                label: _t(ru: 'Любимые', en: 'Favorites'),
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
                Text(
                  _t(ru: 'АКТИВНЫЙ ЗАКАЗ', en: 'ACTIVE ORDER'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(ru: 'Заказов пока нет', en: 'No orders yet'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    ru: 'Откройте каталог, настройте выдачу как на сайте и оформите первый заказ в одном потоке.',
                    en: 'Open the catalog, adjust the feed like on the website, and place the first order in one flow.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          _orderCard(
            order: activeOrder,
            cta: _t(ru: 'ОТСЛЕДИТЬ', en: 'TRACK'),
            onTap: () {
              setState(() {
                _latestOrderId = activeOrder.id;
                _view = ClientView.tracking;
              });
            },
          ),
        const SizedBox(height: 12),
        _sectionLabel(_t(ru: 'БЫСТРЫЙ ВЫБОР', en: 'QUICK PICK')),
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
                  _t(ru: 'Перейти в каталог', en: 'Open Catalog'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AvishuButton(
                text: _t(ru: 'ОТКРЫТЬ', en: 'OPEN'),
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

  Widget _buildCompactCollectionsScreen() {
    final products = _visibleProducts;
    final sectionLabel = _showFavoritesOnly
        ? _t(ru: 'ИЗБРАННОЕ', en: 'FAVORITES')
        : localizeCatalogSection(_language, _activeSection).toUpperCase();
    final filtersSummary = _activeCatalogFiltersCount == 0
        ? _t(ru: '${products.length} моделей', en: '${products.length} items')
        : _t(
            ru: '$_activeCatalogFiltersCount фильтров • ${products.length} моделей',
            en: '$_activeCatalogFiltersCount filters • ${products.length} items',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t(ru: 'ГЛАВНАЯ', en: 'HOME')} / $sectionLabel',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _catalogAccordion(
          eyebrow: _t(ru: 'РАЗДЕЛЫ КАТАЛОГА', en: 'CATALOG SECTIONS'),
          title: sectionLabel,
          summary: _showFavoritesOnly
              ? _t(
                  ru: 'Выбраны сохраненные модели профиля',
                  en: 'Saved profile favorites only',
                )
              : _t(
                  ru: 'Текущий раздел каталога',
                  en: 'Current catalog section',
                ),
          expanded: _catalogSectionsExpanded,
          onToggle: () {
            setState(
              () => _catalogSectionsExpanded = !_catalogSectionsExpanded,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _catalogSectionTile(
                label: _t(ru: 'ИЗБРАННОЕ', en: 'FAVORITES'),
                active: _showFavoritesOnly,
                onTap: () {
                  setState(() {
                    _showFavoritesOnly = true;
                    _catalogSectionsExpanded = false;
                    _resetCatalogFilters();
                  });
                },
              ),
              ...catalogSections.map(
                (section) => _catalogSectionTile(
                  label: localizeCatalogSection(_language, section),
                  active: !_showFavoritesOnly && section == _activeSection,
                  onTap: () {
                    setState(() {
                      _showFavoritesOnly = false;
                      _selectSection(section);
                      _catalogSectionsExpanded = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _catalogAccordion(
          eyebrow: _t(ru: 'ФИЛЬТРЫ И СОРТИРОВКА', en: 'FILTERS & SORTING'),
          title: sectionLabel,
          summary: filtersSummary,
          expanded: _catalogFiltersExpanded,
          onToggle: () {
            setState(() => _catalogFiltersExpanded = !_catalogFiltersExpanded);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sortSelector(),
              const SizedBox(height: 14),
              _catalogCardSizeSelector(),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  setState(_resetCatalogFilters);
                },
                child: Text(
                  _t(ru: 'Очистить выбор', en: 'Clear filters'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _filterGroup(
                title: _t(ru: 'Категория', en: 'Category'),
                options: _categoryOptions,
                selectedValue: _categoryFilter,
                optionLabelBuilder: (value) =>
                    localizeCatalogSection(_language, value),
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              _filterGroup(
                title: _t(ru: 'Размер', en: 'Size'),
                options: _sizeOptions,
                selectedValue: _sizeFilter,
                onChanged: (value) => setState(() => _sizeFilter = value),
              ),
              _filterGroup(
                title: _t(ru: 'Цвет', en: 'Color'),
                options: _colorOptions,
                selectedValue: _colorFilter,
                onChanged: (value) => setState(() => _colorFilter = value),
              ),
              Text(
                _t(ru: 'ЦЕНА', en: 'PRICE'),
                style: AppTypography.eyebrow,
              ),
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
                Text(
                  _t(ru: 'НЕТ СОВПАДЕНИЙ', en: 'NO MATCHES'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 10),
                Text(
                  _showFavoritesOnly
                      ? _t(
                          ru: 'В избранном пока нет моделей. Откройте карточку товара и сохраните ее сердцем.',
                          en: 'No favorite models yet. Open a product card and save it with the heart icon.',
                        )
                      : _t(
                          ru: 'Попробуйте снять один из фильтров или выбрать другой раздел каталога.',
                          en: 'Try clearing a filter or switching to another catalog section.',
                        ),
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

  // ignore: unused_element
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
        _sectionLabel(_t(ru: 'ИСТОРИЯ ЗАКАЗОВ', en: 'ORDER HISTORY')),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _surfaceCard(
            child: Text(
              _t(
                ru: 'История появится после первого оформленного заказа.',
                en: 'History will appear after the first completed checkout.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(
              order: order,
              cta: _t(ru: 'ДЕТАЛИ', en: 'DETAILS'),
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
    final favoriteProducts = _favoriteProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(ru: 'КЛИЕНТСКИЙ ПРОФИЛЬ', en: 'CLIENT PROFILE'),
                style: AppTypography.eyebrow,
              ),
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
                        '${_t(ru: 'РОЛЬ', en: 'ROLE')}: ${localizedRoleLabel(currentRole, _language)}',
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(ru: 'ПРОГРАММА ЛОЯЛЬНОСТИ', en: 'LOYALTY PROGRAM'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: ((orders.length % 4) + 1) / 4),
              const SizedBox(height: 10),
              Text(
                _t(
                  ru: 'ЗАКАЗОВ: ${orders.length} / СЛЕДУЮЩИЙ УРОВЕНЬ: ПРИОРИТЕТ',
                  en: 'ORDERS: ${orders.length} / NEXT LEVEL: PRIORITY',
                ),
                style: AppTypography.code,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          onTap: () {
            setState(() {
              _tab = ClientTab.collections;
              _view = ClientView.root;
              _showFavoritesOnly = true;
              _catalogFiltersExpanded = true;
              _catalogSectionsExpanded = false;
            });
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _t(ru: 'Любимые модели', en: 'Favorite Models'),
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
        if (favoriteProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...favoriteProducts.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _productCard(
                product: product,
                onTap: () => _openProduct(product),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _surfaceCard(
            child: Text(
              _t(
                ru: 'Сохраненные модели появятся здесь и будут открываться как обычные карточки товара.',
                en: 'Saved models will appear here and open like regular product cards.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        if (trackedOrder != null) ...[
          const SizedBox(height: 12),
          _orderCard(
            order: trackedOrder,
            cta: _t(ru: 'ОТСЛЕДИТЬ', en: 'TRACK'),
            onTap: () => setState(() => _view = ClientView.tracking),
          ),
        ],
        const SizedBox(height: 16),
        AvishuButton(
          text: 'WHY AVISHU',
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.arrow_outward,
          onPressed: () => context.push('/why-avishu'),
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
    );
  }

  Widget _buildProductScreen() {
    final product = _selectedProduct!;
    final selectedColor = _selectedColor ?? product.defaultColor;
    final selectedSize = _selectedSize ?? product.defaultSize;
    final isFavorite = _favoriteProductIds.contains(product.id);
    final categoryLabel = localizeCatalogSection(_language, product.category);
    final seasonLabel = localizeCatalogSection(_language, product.season);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t(ru: 'ГЛАВНАЯ', en: 'HOME')} / ${seasonLabel.toUpperCase()} / ${categoryLabel.toUpperCase()} / ${product.title}',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productGallery(product),
              const SizedBox(height: 16),
              Text(categoryLabel.toUpperCase(), style: AppTypography.eyebrow),
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
                  _metaChip(product.availabilityLabelFor(_language)),
                  _metaChip(product.material),
                  _metaChip(product.silhouette.toUpperCase()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: _t(ru: 'ИНФОРМАЦИЯ О ТОВАРЕ', en: 'PRODUCT INFO'),
          rows: [
            OrderInfoRowData(
              label: _t(ru: 'Артикул', en: 'SKU'),
              value: product.sku,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Материал', en: 'Material'),
              value: product.material,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Силуэт', en: 'Silhouette'),
              value: product.silhouette,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Цвет', en: 'Color'),
              value: selectedColor,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Размер', en: 'Size'),
              value: selectedSize,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(ru: 'ЦВЕТ', en: 'COLOR'),
                style: AppTypography.eyebrow,
              ),
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
              Text(
                _t(ru: 'РАЗМЕР', en: 'SIZE'),
                style: AppTypography.eyebrow,
              ),
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
                      _t(ru: 'Размерная сетка', en: 'Size Guide'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (product.preorder) ...[
                const SizedBox(height: 16),
                Text(
                  _t(ru: 'ДАТА ГОТОВНОСТИ', en: 'READY DATE'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dateOptions
                      .map(
                        (date) => _selectionPill(
                          label:
                              '${monthShort(date.month, _language)} ${date.day.toString().padLeft(2, '0')}',
                          selected: _selectedDate == date,
                          onTap: () => setState(() => _selectedDate = date),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                product.inStock
                    ? _t(ru: 'В наличии', en: 'In Stock')
                    : _t(ru: 'Нет в наличии', en: 'Out of Stock'),
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
                      text: isFavorite
                          ? _t(ru: 'В ИЗБРАННОМ', en: 'IN FAVORITES')
                          : _t(ru: 'В ИЗБРАННОЕ', en: 'ADD TO FAVORITES'),
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
                    ? _t(ru: 'ПРОДОЛЖИТЬ ПРЕДЗАКАЗ', en: 'CONTINUE PREORDER')
                    : _t(ru: 'ОФОРМИТЬ ЗАКАЗ', en: 'PLACE ORDER'),
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
          title: _t(ru: 'ОПИСАНИЕ', en: 'DESCRIPTION'),
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
          title: _t(ru: 'ХАРАКТЕРИСТИКИ', en: 'SPECIFICATIONS'),
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
                          flex: 1,
                          child: Text(
                            spec.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(
                            spec.value,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
          title: _t(ru: 'УХОД', en: 'CARE'),
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
          title: _t(ru: 'СОСТАВ ЗАКАЗА', en: 'ORDER SUMMARY'),
          rows: [
            OrderInfoRowData(
              label: _t(ru: 'Изделие', en: 'Product'),
              value: product.title,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Цвет', en: 'Color'),
              value: _selectedColor ?? product.defaultColor,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Размер', en: 'Size'),
              value: _selectedSize ?? product.defaultSize,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Количество', en: 'Quantity'),
              value: '$_quantity',
            ),
            OrderInfoRowData(
              label: _t(ru: 'Стоимость позиции', en: 'Unit Price'),
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
                decoration: InputDecoration(
                  labelText: _t(ru: 'Город', en: 'City'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: _t(ru: 'Адрес', en: 'Address'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apartmentController,
                decoration: InputDecoration(
                  labelText: _t(
                    ru: 'Квартира / офис',
                    en: 'Apartment / Office',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _t(
                    ru: 'Комментарий к заказу',
                    en: 'Order Comment',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionLabel(_t(ru: 'СПОСОБ ПОЛУЧЕНИЯ', en: 'FULFILLMENT METHOD')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _deliveryCard(
                label: DeliveryMethod.courier.labelFor(_language),
                active: _deliveryMethod == DeliveryMethod.courier,
                onTap: () =>
                    setState(() => _deliveryMethod = DeliveryMethod.courier),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _deliveryCard(
                label: DeliveryMethod.pickup.labelFor(_language),
                active: _deliveryMethod == DeliveryMethod.pickup,
                onTap: () =>
                    setState(() => _deliveryMethod = DeliveryMethod.pickup),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: _t(ru: 'ИТОГО', en: 'TOTAL'),
          rows: _checkoutRows(product),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: _t(ru: 'ПЕРЕЙТИ К ОПЛАТЕ', en: 'GO TO PAYMENT'),
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
              Text(
                _t(ru: 'ОПЛАТА КАРТОЙ', en: 'CARD PAYMENT'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardController,
                decoration: InputDecoration(
                  labelText: _t(ru: 'Номер карты', en: 'Card Number'),
                ),
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
          title: _t(ru: 'ДЕТАЛИ ОПЛАТЫ', en: 'PAYMENT DETAILS'),
          rows: _checkoutRows(product),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: _t(ru: 'ОПЛАТИТЬ', en: 'PAY'),
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: _isSubmitting ? null : () => _submitOrder(clientId),
        ),
      ],
    );
  }

  Widget _buildTrackingScreen(OrderModel? order, {String? clientDisplayName}) {
    if (order == null) {
      return _surfaceCard(
        child: Text(
          _t(
            ru: 'Ожидаем синхронизацию заказа.',
            en: 'Waiting for order synchronization.',
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderDigitalTwinCard(
          order: order,
          clientDisplayName: clientDisplayName,
        ),
        const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              AvishuOrderTracker(status: order.status),
              const SizedBox(height: 10),
              Text(
                '${_t(ru: 'СТАТУС', en: 'STATUS')} / ${order.status.clientLabelFor(_language)}',
                style: AppTypography.code,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(
          title: _t(ru: 'ДЕТАЛИ ЗАКАЗА', en: 'ORDER DETAILS'),
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
                label: _t(ru: 'Статус', en: 'Status'),
                value: order.franchiseeNote,
              ),
            ],
          ),
        ],
        if (order.productionNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(ru: 'ПОМЕТКА ПРОИЗВОДСТВА', en: 'FACTORY NOTE'),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Производство', en: 'Factory'),
                value: order.productionNote,
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AvishuButton(
                text: _t(ru: 'НАЗАД', en: 'BACK'),
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
                text: _t(ru: 'КАТАЛОГ', en: 'CATALOG'),
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
    if (_isSubmitting) return;
    final product = _selectedProduct!;
    if (!_validateCheckoutFields() || !_validatePaymentFields()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
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

      if (!mounted) return;
      setState(() {
        _latestOrderId = orderId;
        _tab = ClientTab.dashboard;
        _view = ClientView.tracking;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateCheckoutFields() {
    if (_cityController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      _showMessage(
        _t(
          ru: 'Заполните город и адрес доставки.',
          en: 'Fill in the city and delivery address.',
        ),
      );
      return false;
    }
    return true;
  }

  bool _validatePaymentFields() {
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4 ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().length < 3) {
      _showMessage(
        _t(
          ru: 'Проверьте данные банковской карты.',
          en: 'Check the bank card details.',
        ),
      );
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
      _view = ClientView.product;
      _selectedImageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
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
    _showFavoritesOnly = false;
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
      '${_t(ru: 'Цвет', en: 'Color')}: ${_selectedColor ?? product.defaultColor}',
      '${_t(ru: 'Количество', en: 'Quantity')}: $_quantity',
      if (customerNote.isNotEmpty)
        '${_t(ru: 'Комментарий клиента', en: 'Client Comment')}: $customerNote',
    ];
    return lines.join('\n');
  }

  List<OrderInfoRowData> _checkoutRows(CatalogProduct product) {
    return [
      OrderInfoRowData(
        label: _t(ru: 'Изделие', en: 'Product'),
        value: product.title,
      ),
      OrderInfoRowData(
        label: _t(ru: 'Цвет', en: 'Color'),
        value: _selectedColor ?? product.defaultColor,
      ),
      OrderInfoRowData(
        label: _t(ru: 'Размер', en: 'Size'),
        value: _selectedSize ?? product.defaultSize,
      ),
      OrderInfoRowData(
        label: _t(ru: 'Количество', en: 'Quantity'),
        value: '$_quantity',
      ),
      OrderInfoRowData(
        label: _t(ru: 'Стоимость', en: 'Subtotal'),
        value: formatCurrency(product.price * _quantity),
      ),
      OrderInfoRowData(
        label: _t(ru: 'Доставка', en: 'Delivery'),
        value:
            '${_deliveryMethod.labelFor(_language)} / ${formatCurrency(_deliveryMethod.fee)}',
      ),
      if (product.preorder && _selectedDate != null)
        OrderInfoRowData(
          label: _t(ru: 'Дата готовности', en: 'Ready Date'),
          value: formatDate(_selectedDate!),
        ),
      OrderInfoRowData(
        label: _t(ru: 'Итого', en: 'Total'),
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

  Widget _catalogAccordion({
    required String eyebrow,
    required String title,
    required String summary,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow, style: AppTypography.eyebrow),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  expanded ? Icons.remove : Icons.add,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
          if (expanded) ...[const SizedBox(height: 18), child],
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
                child: Text(option.labelFor(_language)),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_t(ru: 'СОРТИРОВАТЬ', en: 'SORT')}: ${_sortOption.labelFor(_language).toUpperCase()}',
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

  Widget _catalogCardSizeSelector() {
    final settingsController = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(ru: 'РАЗМЕР КАРТОЧЕК', en: 'CARD SIZE'),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: 8),
        Row(
          children: CatalogCardSize.values.map((size) {
            final isActive = _catalogCardSize == size;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: size == CatalogCardSize.large ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => settingsController.setCatalogCardSize(size),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.black
                          : AppColors.surfaceLowest,
                      border: Border.all(color: AppColors.black),
                    ),
                    child: Text(
                      '${catalogCardSizeLabel(size)} / ${_t(ru: size == CatalogCardSize.compact
                          ? 'МЕНЬШЕ'
                          : size == CatalogCardSize.standard
                          ? 'БАЛАНС'
                          : 'КРУПНЕЕ', en: size == CatalogCardSize.compact
                          ? 'SMALL'
                          : size == CatalogCardSize.standard
                          ? 'BALANCED'
                          : 'LARGE')}',
                      textAlign: TextAlign.center,
                      style: AppTypography.button.copyWith(
                        color: isActive ? AppColors.white : AppColors.black,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _filterGroup({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    String Function(String value)? optionLabelBuilder,
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
                label: _t(ru: 'Все', en: 'All'),
                selected: selectedValue == null,
                onTap: () => onChanged(null),
              ),
              ...options.map(
                (option) => _selectionPill(
                  label: optionLabelBuilder?.call(option) ?? option,
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
    return SizedBox(
      height: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.code.copyWith(fontSize: 9),
        ),
      ),
    );
  }

  Widget _productGallery(CatalogProduct product) {
    final isFavorite = _favoriteProductIds.contains(product.id);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.8,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: product.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _selectedImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _networkProductImage(product.imageUrls[index]);
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _metaChip(
                  localizeCatalogSection(_language, product.season),
                ),
              ),
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
              // Счётчик страниц (точки или текст) в стиле брутализма
              if (product.imageUrls.length > 1)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: AppColors.black,
                    child: Text(
                      '${_selectedImageIndex + 1} / ${product.imageUrls.length}',
                      style: AppTypography.code.copyWith(
                        color: AppColors.white,
                        fontSize: 10,
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
                onTap: () {
                  setState(() => _selectedImageIndex = index);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
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

  double get _catalogCardAspectRatio {
    switch (_catalogCardSize) {
      case CatalogCardSize.compact:
        return 1.08;
      case CatalogCardSize.standard:
        return 0.88;
      case CatalogCardSize.large:
        return 0.72;
    }
  }

  double get _catalogCardContentSpacing {
    switch (_catalogCardSize) {
      case CatalogCardSize.compact:
        return 10;
      case CatalogCardSize.standard:
        return 14;
      case CatalogCardSize.large:
        return 18;
    }
  }

  int get _catalogCardDescriptionLines {
    switch (_catalogCardSize) {
      case CatalogCardSize.compact:
        return 2;
      case CatalogCardSize.standard:
        return 3;
      case CatalogCardSize.large:
        return 4;
    }
  }

  Widget _productCard({
    required CatalogProduct product,
    required VoidCallback onTap,
  }) {
    final isFavorite = _favoriteProductIds.contains(product.id);
    final categoryLabel = localizeCatalogSection(_language, product.category);

    return _surfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _catalogCardAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _networkProductImage(
                    product.imageUrls.first,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(top: 12, left: 12, child: _metaChip(categoryLabel)),
                if (product.isNew)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _metaChip(_t(ru: 'Новинка', en: 'New')),
                  ),
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
          SizedBox(height: _catalogCardContentSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: (_catalogCardSize == CatalogCardSize.compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge),
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
            maxLines: _catalogCardDescriptionLines,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(product.availabilityLabelFor(_language)),
              _metaChip(product.defaultSize),
              _metaChip(
                _t(
                  ru: '${product.colors.length} цвета',
                  en: '${product.colors.length} colors',
                ),
              ),
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
              _t(ru: 'СПОСОБ', en: 'METHOD'),
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
                        Text(
                          _t(ru: 'РАЗДЕЛЫ КАТАЛОГА', en: 'CATALOG SECTIONS'),
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            ru: 'Быстрый переход по коллекциям в мобильной адаптации.',
                            en: 'Fast navigation between collections in mobile mode.',
                          ),
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ...catalogSections.map(
                          (section) => _catalogSectionTile(
                            label: localizeCatalogSection(_language, section),
                            active:
                                !_showFavoritesOnly &&
                                section == _activeSection,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              setState(() => _selectSection(section));
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        AvishuButton(
                          text: _t(ru: 'НАСТРОЙКИ', en: 'SETTINGS'),
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
                          _t(ru: 'РАЗМЕРНАЯ СЕТКА', en: 'SIZE GUIDE'),
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
    final title = switch (group.title) {
      'Базовые размеры' => _t(ru: 'БАЗОВЫЕ РАЗМЕРЫ', en: 'BASE SIZES'),
      'Размеры Plus (+20% к стоимости)' => _t(
        ru: 'РАЗМЕРЫ PLUS (+20% К СТОИМОСТИ)',
        en: 'PLUS SIZES (+20% PRICE)',
      ),
      _ => group.title.toUpperCase(),
    };
    final unit = _language == AppLanguage.russian ? group.unitLabel : 'CM';

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
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(unit.toUpperCase(), style: AppTypography.code),
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
                    _t(ru: 'Обхват груди', en: 'Bust'),
                    group.columns.map((column) => column.chest).toList(),
                  ),
                  _measurementRow(
                    _t(ru: 'Обхват талии', en: 'Waist'),
                    group.columns.map((column) => column.waist).toList(),
                  ),
                  _measurementRow(
                    _t(ru: 'Обхват бедер', en: 'Hips'),
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
