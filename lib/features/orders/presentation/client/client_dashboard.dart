import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/delivery_method.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/services/order_geocoding_service.dart';
import '../../../orders/domain/services/order_map_location_resolver.dart';
import '../../../products/data/product_repository.dart';
import '../../../users/data/user_profile_repository.dart';
import '../../../users/domain/models/user_profile.dart';
import '../../../users/domain/services/loyalty_program.dart';
import '../shared/order_digital_twin_card.dart';
import '../shared/order_delivery_map_card.dart';
import '../shared/order_formatters.dart';
import '../shared/order_panels.dart';
import '../shared/desk_help/desk_help.dart';
import 'catalog_sections/molecules/client_catalog_media_carousel.dart';
import 'client_data.dart';
import 'dashboard_sections/client_dashboard_sections.dart';

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

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return Stream.value(null);
  }
  return ref.watch(userProfileRepositoryProvider).watchById(currentUser.uid);
});

final checkoutPreviewRouteProvider = FutureProvider.autoDispose
    .family<
      OrderRouteLocations,
      ({
        DeliveryMethod deliveryMethod,
        String city,
        String address,
        String apartment,
      })
    >((ref, request) async {
      return ref
          .watch(orderGeocodingServiceProvider)
          .resolveRoute(
            deliveryMethod: request.deliveryMethod,
            city: request.city,
            address: request.address,
            apartment: request.apartment,
          );
    });

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard> {
  static const _favoriteProductIdsKey = 'client.favorite_product_ids';
  static const double _priceFilterMin = 0;
  static const double _priceFilterStep = 200;
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
  bool _applyLoyaltyDiscount = true;
  bool _useBonusBalance = false;
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
  late ScrollController _thumbnailScrollController;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(_priceFilterMin, _snappedCatalogMaxPrice);
    _pageController = PageController();
    _thumbnailScrollController = ScrollController();
    _loadFavoriteProductIds();
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
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  double get _catalogMaxPrice => _catalogProducts
      .map((product) => product.price)
      .reduce((a, b) => a > b ? a : b);

  double get _snappedCatalogMaxPrice =>
      _snapPriceToStep(_catalogMaxPrice, roundUp: true);

  int get _priceRangeDivisions =>
      ((_snappedCatalogMaxPrice - _priceFilterMin) / _priceFilterStep).round();

  AppLanguage get _language => ref.read(appSettingsProvider).language;

  CatalogCardSize get _catalogCardSize =>
      ref.read(appSettingsProvider).catalogCardSize;

  String _t({required String ru, required String en, String? kk}) {
    return tr(_language, ru: ru, en: en, kk: kk);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(ru: 'ПАНЕЛЬ', en: 'HOME', kk: 'ПАНЕЛЬ'),
      icon: Icons.grid_view_rounded,
    ),
    AvishuNavItem(
      label: _t(ru: 'КАТАЛОГ', en: 'CATALOG', kk: 'КАТАЛОГ'),
      icon: Icons.layers_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ИСТОРИЯ', en: 'ORDERS', kk: 'ТАРИХЫ'),
      icon: Icons.inventory_2_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ПРОФИЛЬ', en: 'PROFILE', kk: 'ПРОФИЛЬ'),
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
    if (_priceRange.start != _priceFilterMin ||
        _priceRange.end != _snappedCatalogMaxPrice) {
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
          return _t(
            ru: 'КЛИЕНТ / ТОВАР',
            en: 'CLIENT / PRODUCT',
            kk: 'КЛИЕНТ / ТАУАР',
          );
        }
        return '${_t(ru: 'КЛИЕНТ', en: 'CLIENT', kk: 'КЛИЕНТ')} / '
            '${localizeCatalogSection(_language, _selectedProduct!.category).toUpperCase()}';
      case ClientView.checkout:
        return _t(
          ru: 'КЛИЕНТ / ОФОРМЛЕНИЕ',
          en: 'CLIENT / CHECKOUT',
          kk: 'КЛИЕНТ / ТАПСЫРЫС',
        );
      case ClientView.payment:
        return _t(
          ru: 'КЛИЕНТ / ОПЛАТА',
          en: 'CLIENT / PAYMENT',
          kk: 'КЛИЕНТ / ТӨЛЕМ',
        );
      case ClientView.tracking:
        return _t(
          ru: 'КЛИЕНТ / ТРЕКИНГ',
          en: 'CLIENT / TRACKING',
          kk: 'КЛИЕНТ / БАҚЫЛАУ',
        );
      case ClientView.root:
        switch (_tab) {
          case ClientTab.dashboard:
            return _t(
              ru: 'КЛИЕНТ / ПАНЕЛЬ',
              en: 'CLIENT / HOME',
              kk: 'КЛИЕНТ / ПАНЕЛЬ',
            );
          case ClientTab.collections:
            return _t(
              ru: 'КЛИЕНТ / КАТАЛОГ',
              en: 'CLIENT / CATALOG',
              kk: 'КЛИЕНТ / КАТАЛОГ',
            );
          case ClientTab.archive:
            return _t(
              ru: 'КЛИЕНТ / ИСТОРИЯ',
              en: 'CLIENT / ORDERS',
              kk: 'КЛИЕНТ / ТАРИХЫ',
            );
          case ClientTab.profile:
            return _t(
              ru: 'КЛИЕНТ / ПРОФИЛЬ',
              en: 'CLIENT / PROFILE',
              kk: 'КЛИЕНТ / ПРОФИЛЬ',
            );
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
          title: _t(
            ru: 'КАПСУЛА СЕЗОНА',
            en: 'SEASON CAPSULE',
            kk: 'МАУСЫМДЫҚ КАПСУЛА',
          ),
          subtitle: _t(
            ru: 'Каталог собран с разделами, фильтрами, сортировкой и полноценной карточкой товара в фирменном AVISHU-ритме.',
            en: 'The catalog now combines sections, filters, sorting, and a full product card in the AVISHU rhythm.',
            kk: 'Каталог бөлімдермен, сүзгілермен, сұрыптаумен және фирмалық AVISHU-ырғағындағы толыққанды тауар карточкасымен жинақталған.',
          ),
          accent: _t(
            ru: 'НОВЫХ МОДЕЛЕЙ: ${_catalogProducts.where((item) => item.isNew).length}',
            en: 'NEW MODELS: ${_catalogProducts.where((item) => item.isNew).length}',
            kk: 'ЖАҢА МОДЕЛЬДЕР: ${_catalogProducts.where((item) => item.isNew).length}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: _t(
                  ru: 'Предзаказы',
                  en: 'Preorders',
                  kk: 'Алдын ала тапсырыстар',
                ),
                value: preorderCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                label: _t(ru: 'Любимые', en: 'Favorites', kk: 'Таңдаулылар'),
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
                  _t(
                    ru: 'АКТИВНЫЙ ЗАКАЗ',
                    en: 'ACTIVE ORDER',
                    kk: 'БЕЛСЕНДІ ТАПСЫРЫС',
                  ),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    ru: 'Заказов пока нет',
                    en: 'No orders yet',
                    kk: 'Әзірге тапсырыстар жоқ',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    ru: 'Откройте каталог, настройте выдачу как на сайте и оформите первый заказ в одном потоке.',
                    en: 'Open the catalog, adjust the feed like on the website, and place the first order in one flow.',
                    kk: 'Каталогты ашыңыз, сайттағы сияқты көрсетілімді реттеңіз және бір лекпен алғашқы тапсырысты ресімдеңіз.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          _orderCard(
            order: activeOrder,
            cta: _t(ru: 'ОТСЛЕДИТЬ', en: 'TRACK', kk: 'БАҚЫЛАУ'),
            onTap: () {
              setState(() {
                _latestOrderId = activeOrder.id;
                _view = ClientView.tracking;
              });
            },
          ),
        const SizedBox(height: 12),
        _sectionLabel(
          _t(ru: 'БЫСТРЫЙ ВЫБОР', en: 'QUICK PICK', kk: 'ЖЕДЕЛ ТАҢДАУ'),
        ),
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
                  _t(
                    ru: 'Перейти в каталог',
                    en: 'Open Catalog',
                    kk: 'Каталогқа өту',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AvishuButton(
                text: _t(ru: 'ОТКРЫТЬ', en: 'OPEN', kk: 'АШУ'),
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
        ? _t(ru: 'ИЗБРАННОЕ', en: 'FAVORITES', kk: 'ТАҢДАУЛЫЛАР')
        : localizeCatalogSection(_language, _activeSection).toUpperCase();
    final filtersSummary = _activeCatalogFiltersCount == 0
        ? _t(
            ru: '${products.length} моделей',
            en: '${products.length} items',
            kk: '${products.length} модель',
          )
        : _t(
            ru: '$_activeCatalogFiltersCount фильтров • ${products.length} моделей',
            en: '$_activeCatalogFiltersCount filters вЂў ${products.length} items',
            kk: '$_activeCatalogFiltersCount сүзгі • ${products.length} модель',
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
          eyebrow: _t(
            ru: 'РАЗДЕЛЫ КАТАЛОГА',
            en: 'CATALOG SECTIONS',
            kk: 'КАТАЛОГ БӨЛІМДЕРІ',
          ),
          title: sectionLabel,
          summary: _showFavoritesOnly
              ? _t(
                  ru: 'Выбраны сохраненные модели профиля',
                  en: 'Saved profile favorites only',
                  kk: 'Профильдегі сақталған модельдер таңдалды',
                )
              : _t(
                  ru: 'Текущий раздел каталога',
                  en: 'Current catalog section',
                  kk: 'Каталогтың ағымдағы бөлімі',
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
                label: _t(ru: 'ИЗБРАННОЕ', en: 'FAVORITES', kk: 'ТАҢДАУЛЫЛАР'),
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
          eyebrow: _t(
            ru: 'ФИЛЬТРЫ И СОРТИРОВКА',
            en: 'FILTERS & SORTING',
            kk: 'СҮЗГІЛЕР ЖӘНЕ СҰРЫПТАУ',
          ),
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
                  _t(
                    ru: 'Очистить выбор',
                    en: 'Clear filters',
                    kk: 'Таңдауды тазарту',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _filterGroup(
                title: _t(ru: 'Категория', en: 'Category', kk: 'Санат'),
                options: _categoryOptions,
                selectedValue: _categoryFilter,
                optionLabelBuilder: (value) =>
                    localizeCatalogSection(_language, value),
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              _filterGroup(
                title: _t(ru: 'Размер', en: 'Size', kk: 'Өлшем'),
                options: _sizeOptions,
                selectedValue: _sizeFilter,
                onChanged: (value) => setState(() => _sizeFilter = value),
              ),
              _filterGroup(
                title: _t(ru: 'Цвет', en: 'Color', kk: 'Түс'),
                options: _colorOptions,
                selectedValue: _colorFilter,
                onChanged: (value) => setState(() => _colorFilter = value),
              ),
              Text(
                _t(ru: 'ЦЕНА', en: 'PRICE', kk: 'БАҒА'),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 10),
              _CatalogPriceRangeSlider(
                min: _priceFilterMin,
                max: _snappedCatalogMaxPrice,
                divisions: _priceRangeDivisions,
                values: _priceRange,
                onChangedEnd: (values) {
                  setState(() => _priceRange = values);
                },
                valueFormatter: formatCurrency,
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
                  _t(
                    ru: 'НЕТ СОВПАДЕНИЙ',
                    en: 'NO MATCHES',
                    kk: 'СӘЙКЕСТІК ЖОҚ',
                  ),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 10),
                Text(
                  _showFavoritesOnly
                      ? _t(
                          ru: 'В избранном пока нет моделей. Откройте карточку товара и сохраните ее сердцем.',
                          en: 'No favorite models yet. Open a product card and save it with the heart icon.',
                          kk: 'Таңдаулыда әзірге модельдер жоқ. Тауар карточкасын ашып, оны жүрекшемен сақтаңыз.',
                        )
                      : _t(
                          ru: 'Попробуйте снять один из фильтров или выбрать другой раздел каталога.',
                          en: 'Try clearing a filter or switching to another catalog section.',
                          kk: 'Сүзгілердің бірін алып тастап көріңіз немесе каталогтың басқа бөлімін таңдаңыз.',
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
              _CatalogPriceRangeSlider(
                min: _priceFilterMin,
                max: _snappedCatalogMaxPrice,
                divisions: _priceRangeDivisions,
                values: _priceRange,
                onChangedEnd: (values) {
                  setState(() => _priceRange = values);
                },
                valueFormatter: formatCurrency,
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
        _sectionLabel(
          _t(
            ru: 'ИСТОРИЯ ЗАКАЗОВ',
            en: 'ORDER HISTORY',
            kk: 'ТАПСЫРЫСТАР МҰРАҒАТЫ',
          ),
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _surfaceCard(
            child: Text(
              _t(
                ru: 'История появится после первого оформленного заказа.',
                en: 'History will appear after the first completed checkout.',
                kk: 'Тарих алғашқы тапсырыстан кейін пайда болады.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(
              order: order,
              cta: _t(ru: 'ДЕТАЛИ', en: 'DETAILS', kk: 'МӘЛІМЕТТЕР'),
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
    final compact = ref.watch(appSettingsProvider).compactCards;
    final user = ref.watch(currentUserProvider).value;
    final profile = ref.watch(currentUserProfileProvider).value;
    final favoriteProducts = _favoriteProducts;
    final loyalty = _loyaltySnapshot(profile, orders);
    final supportOrder =
        trackedOrder ?? (orders.isNotEmpty ? orders.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  ru: 'КЛИЕНТСКИЙ ПРОФИЛЬ',
                  en: 'CLIENT PROFILE',
                  kk: 'КЛИЕНТ ПРОФИЛІ',
                ),
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
                        '${_t(ru: 'РОЛЬ', en: 'ROLE', kk: 'РӨЛІ')}: ${localizedRoleLabel(currentRole, _language)}',
                        style: AppTypography.button.copyWith(
                          color: AppColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    Text(
                      _t(ru: 'ТЕКУЩАЯ', en: 'CURRENT', kk: 'АҒЫМДАҒЫ'),
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
                _t(
                  ru: 'ПРОГРАММА ЛОЯЛЬНОСТИ',
                  en: 'LOYALTY PROGRAM',
                  kk: 'ЛОЯЛЬДІЛІК БАҒДАРЛАМАСЫ',
                ),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              Text(
                loyalty.currentTier.titleFor(_language),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: loyalty.progressToNextTier),
              const SizedBox(height: 10),
              Text(
                loyalty.currentTier.perksFor(_language),
                style: AppTypography.code,
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
                children: [
                  Expanded(
                    child: _metricCard(
                      label: _t(ru: 'ПОТРАЧЕНО', en: 'SPENT', kk: 'ЖҰМСАЛДЫ'),
                      value: formatCurrency(loyalty.totalSpent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricCard(
                      label: _t(ru: 'БОНУСЫ', en: 'BONUSES', kk: 'БОНУСТАР'),
                      value: formatCurrency(loyalty.bonusBalance),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                loyalty.nextTier == null
                    ? _t(
                        ru: 'Максимальный уровень уже открыт.',
                        en: 'Top tier already unlocked.',
                        kk: 'Ең жоғары деңгей ашылған.',
                      )
                    : _t(
                        ru: 'До уровня ${loyalty.nextTier!.titleFor(_language)} осталось ${formatCurrency(loyalty.amountToNextTier)}.',
                        en: '${formatCurrency(loyalty.amountToNextTier)} left to reach ${loyalty.nextTier!.titleFor(_language)}.',
                        kk: '${loyalty.nextTier!.titleFor(_language)} деңгейіне дейін ${formatCurrency(loyalty.amountToNextTier)} қалды.',
                      ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  ru: 'Порог считается по сумме оплаченных покупок, а не по количеству заказов.',
                  en: 'Tiers are based on total paid spend, not on order count.',
                  kk: 'Деңгейлер тапсырыс санына емес, төленген сатып алу сомасына байланысты.',
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
                  _t(
                    ru: 'Понравившиеся',
                    en: 'Favorite Models',
                    kk: 'Таңдаулы модельдер',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _favoriteProductIds.length.toString(),
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
                kk: 'Сақталған модельдер осында пайда болады және әдеттегі тауар карточкалары сияқты ашылады.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        if (trackedOrder != null) ...[
          const SizedBox(height: 12),
          _orderCard(
            order: trackedOrder,
            cta: _t(ru: 'ОТСЛЕДИТЬ', en: 'TRACK', kk: 'БАҚЫЛАУ'),
            onTap: () => setState(() => _view = ClientView.tracking),
          ),
        ],
        const SizedBox(height: 12),
        _buildProfileHelpLauncher(
          compact: compact,
          user: user,
          supportOrder: supportOrder,
        ),
        const SizedBox(height: 16),
        AvishuButton(
          text: _t(ru: 'ПОЧЕМУ AVISHU', en: 'WHY AVISHU', kk: 'НЕГЕ AVISHU'),
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.arrow_outward,
          onPressed: () => context.push('/why-avishu'),
        ),
        const SizedBox(height: 16),
        AvishuButton(
          text: _t(
            ru: 'ВЫЙТИ ИЗ АККАУНТА',
            en: 'SIGN OUT',
            kk: 'АККАУНТТАН ШЫҒУ',
          ),
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

  Widget _buildProfileHelpLauncher({
    required bool compact,
    required AppUser? user,
    required OrderModel? supportOrder,
  }) {
    return DeskHelpLauncherSection(
      compact: compact,
      eyebrow: _t(
        ru: 'РРќРЎРўР РЈРљР¦РРЇ Р РџРћР”Р”Р•Р Р–РљРђ',
        en: 'GUIDE & SUPPORT',
        kk: 'РќРҰРЎТљРђРЈР›Р«Рљ РџР•Рќ ТљРћР›Р”РђРЈ',
      ),
      title: _t(
        ru: 'РћС‚РєСЂРѕР№С‚Рµ РёРЅСЃС‚СЂСѓРєС†РёСЋ РёР»Рё С‡Р°С‚ РїРѕ РЅР°Р¶Р°С‚РёСЋ.',
        en: 'Open the guide or support chat in one tap.',
        kk: 'РќС±СЃТ›Р°СѓР»С‹Т›С‚С‹ РЅРµРјРµСЃРµ Т›РѕР»РґР°Сѓ С‡Р°С‚С‹РЅ Р±С–СЂ Р±Р°С‚С‹СЂРјР°РјРµРЅ Р°С€С‹ТЈС‹Р·.',
      ),
      description: _t(
        ru: 'Р”Р»РёРЅРЅС‹Рµ Р±Р»РѕРєРё Р±РѕР»СЊС€Рµ РЅРµ Р·Р°РЅРёРјР°СЋС‚ СЌРєСЂР°РЅ: РёРЅСЃС‚СЂСѓРєС†РёСЏ, СЃРёСЃС‚РµРјРЅС‹Р№ РїРѕС‚РѕРє Рё РїРѕРґРґРµСЂР¶РєР° РѕС‚РєСЂС‹РІР°СЋС‚СЃСЏ РѕС‚РґРµР»СЊРЅРѕ.',
        en: 'Long help blocks no longer take over the screen: the guide, system flow, and support open separately.',
        kk: 'Р¦РµРЅС‚СЂР»С‹ Р±Р»РѕРєС‚Р°СЂ СЌРєСЂР°РЅРґС‹ Р°Р»РјР°Р№РґС‹: РЅС±СЃТ›Р°СѓР»С‹Т›, Р¶ТЇР№Рµ Р°Т“С‹РЅС‹ Р¶У™РЅРµ Т›РѕР»РґР°Сѓ Р±У©Р»РµРє Р°С€С‹Р»Р°РґС‹.',
      ),
      actions: [
        DeskHelpLauncherAction(
          icon: Icons.menu_book_outlined,
          title: _t(
            ru: 'РљР°Рє РїРѕР»СЊР·РѕРІР°С‚СЊСЃСЏ',
            en: 'How to use',
            kk: 'ТљР°Р»Р°Р№ РїР°Р№РґР°Р»Р°РЅСѓ РєРµСЂРµРє',
          ),
          description: _t(
            ru: 'РћС‚РєСЂРѕР№С‚Рµ РєРѕСЂРѕС‚РєСѓСЋ РёРЅСЃС‚СЂСѓРєС†РёСЋ Рё СЃРёСЃС‚РµРјРЅС‹Р№ РїРѕС‚РѕРє Р·Р°РєР°Р·Р°.',
            en: 'Open the quick guide and the full order flow.',
            kk: 'ТљС‹СЃТ›Р° РЅС±СЃТ›Р°СѓР»С‹Т›С‚С‹ Р¶У™РЅРµ С‚Р°РїСЃС‹СЂС‹СЃ Р°Т“С‹РЅС‹РЅ Р°С€С‹ТЈС‹Р·.',
          ),
          actionLabel: _t(ru: 'OPEN', en: 'OPEN', kk: 'OPEN'),
          onTap: () => showDeskHelpSheet(
            context,
            eyebrow: _t(
              ru: 'РљРђРљ РџРћР›Р¬Р—РћР’РђРўР¬РЎРЇ',
              en: 'HOW TO USE',
              kk: 'ТљРђР›РђР™ РџРђР™Р”РђР›РђРќРЈ РљР•Р Р•Рљ',
            ),
            title: _t(
              ru: 'Р’СЃСЏ Р»РѕРіРёРєР° Р·Р°РєР°Р·Р° РІ РѕРґРЅРѕРј РѕРєРЅРµ.',
              en: 'The whole order flow lives in one place.',
              kk: 'РўР°РїСЃС‹СЂС‹СЃ Р»РѕРіРёРєР°СЃС‹ Р±С–СЂ Р¶РµСЂРґРµ.',
            ),
            description: _t(
              ru: 'Р—РґРµСЃСЊ РјРѕР¶РЅРѕ Р±С‹СЃС‚СЂРѕ РїРѕРЅСЏС‚СЊ РєР°Рє РёРґС‘С‚ РѕС„РѕСЂРјР»РµРЅРёРµ, С‚СЂРµРєРёРЅРі Рё РєС‚Рѕ РїРѕРґС…РІР°С‚С‹РІР°РµС‚ Р·Р°РєР°Р· РЅР° РєР°Р¶РґРѕРј СЌС‚Р°РїРµ.',
              en: 'Use this sheet to understand checkout, tracking, and who takes over the order at each stage.',
              kk: 'РћСЃС‹ Р±Р»РѕРєС‚Р° СЂУ™СЃС–РјРґРµСѓРґС–, Р±Р°Т›С‹Р»Р°СѓРґС‹ Р¶У™РЅРµ У™СЂ РєРµР·РµТЈРґРµ С‚Р°РїСЃС‹СЂС‹СЃС‚С‹ РєС–Рј Р°Р»Р°С‚С‹РЅС‹РЅ С‚РµР· С‚ТЇСЃС–РЅСѓРіРµ Р±РѕР»Р°РґС‹.',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileGuideSection(compact: compact),
                const SizedBox(height: 12),
                _buildProfileFlowSection(compact: compact),
              ],
            ),
          ),
        ),
        DeskHelpLauncherAction(
          icon: Icons.forum_outlined,
          title: _t(
            ru: 'Р§Р°С‚ СЃ РїРѕРґРґРµСЂР¶РєРѕР№',
            en: 'Support chat',
            kk: 'ТљРѕР»РґР°Сѓ С‡Р°С‚С‹',
          ),
          description: _t(
            ru: 'РћС‚РєСЂРѕР№С‚Рµ Р±С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ Рё СЃРєРѕРїРёСЂСѓР№С‚Рµ РіРѕС‚РѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ РґР»СЏ РїРѕРґРґРµСЂР¶РєРё.',
            en: 'Open quick actions and copy a ready message for support.',
            kk: 'РўРµР· У™СЂРµРєРµС‚С‚РµСЂРґС– Р°С€С‹Рї, Т›РѕР»РґР°СѓТ“Р° Р°СЂРЅР°Р»Т“Р°РЅ РґР°Р№С‹РЅ С…Р°Р±Р°СЂР»Р°РјР°РЅС‹ РєУ©С€С–СЂС–ТЈС–Р·.',
          ),
          actionLabel: _t(ru: 'CHAT', en: 'CHAT', kk: 'CHAT'),
          emphasized: true,
          onTap: () => showDeskHelpSheet(
            context,
            eyebrow: _t(
              ru: 'РџРћРњРћР©Р¬ Р РџРћР”Р”Р•Р Р–РљРђ',
              en: 'HELP & SUPPORT',
              kk: 'РљУЁРњР•Рљ Р–УРќР• ТљРћР›Р”РђРЈ',
            ),
            title: _t(
              ru: 'Р§Р°С‚ Рё РїРѕРґРґРµСЂР¶РєР° AVISHU',
              en: 'AVISHU support chat',
              kk: 'AVISHU Т›РѕР»РґР°Сѓ С‡Р°С‚С‹',
            ),
            description: _t(
              ru: 'Р—РґРµСЃСЊ РјРѕР¶РЅРѕ Р±С‹СЃС‚СЂРѕ СЃРѕР±СЂР°С‚СЊ РіРѕС‚РѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ РґР»СЏ Р°РґСЂРµСЃР°, РѕРїР»Р°С‚С‹ РёР»Рё РЅРѕРјРµСЂР° Р·Р°РєР°Р·Р°.',
              en: 'Use this sheet to prepare a ready support message with your address, payment, or order details.',
              kk: 'РћСЃС‹ Р¶РµСЂРґРµ РјРµРєРµРЅР¶Р°Р№, С‚У©Р»РµРј РЅРµРјРµСЃРµ С‚Р°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС– Р±Р°СЂ РґР°Р№С‹РЅ Т›РѕР»РґР°Сѓ С…Р°Р±Р°СЂР»Р°РјР°СЃС‹РЅ Р¶РёРЅР°СЃС‚С‹СЂСѓТ“Р° Р±РѕР»Р°РґС‹.',
            ),
            child: _buildProfileSupportSection(
              compact: compact,
              user: user,
              supportOrder: supportOrder,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileGuideSection({required bool compact}) {
    return DeskHelpGuideSection(
      compact: compact,
      eyebrow: _t(
        ru: 'РљРђРљ РџРћР›Р¬Р—РћР’РђРўР¬РЎРЇ',
        en: 'HOW TO USE',
        kk: 'ТљРђР›РђР™ РџРђР™Р”РђР›РђРќРЈ РљР•Р Р•Рљ',
      ),
      title: _t(
        ru: 'Р’СЃРµ РІР°Р¶РЅРѕРµ РїРѕ Р·Р°РєР°Р·Сѓ СЃРѕР±СЂР°РЅРѕ РІ РѕРґРЅРѕРј СЂРёС‚РјРµ.',
        en: 'Everything important about your order lives in one flow.',
        kk: 'РўР°РїСЃС‹СЂС‹СЃ Р±РѕР№С‹РЅС€Р° РјР°ТЈС‹Р·РґС‹РЅС‹ТЈ Р±У™СЂС– Р±С–СЂ Р°Т“С‹РЅРґР° Р¶РёРЅР°Р»Т“Р°РЅ.',
      ),
      description: _t(
        ru: 'РљР°С‚Р°Р»РѕРі, РѕС„РѕСЂРјР»РµРЅРёРµ, РѕРїР»Р°С‚Р° Рё С‚СЂРµРєРёРЅРі СЃРІСЏР·Р°РЅС‹ РјРµР¶РґСѓ СЃРѕР±РѕР№, РїРѕСЌС‚РѕРјСѓ РЅРµ РЅСѓР¶РЅРѕ РёСЃРєР°С‚СЊ СЃС‚Р°С‚СѓСЃ РїРѕ СЂР°Р·РЅС‹Рј СЌРєСЂР°РЅР°Рј.',
        en: 'Catalog, checkout, payment, and tracking are connected, so you do not need to search for status across different screens.',
        kk: 'РљР°С‚Р°Р»РѕРі, СЂУ™СЃС–РјРґРµСѓ, С‚У©Р»РµРј Р¶У™РЅРµ Р±Р°Т›С‹Р»Р°Сѓ Р±С–СЂ Р¶ТЇР№РµРіРµ Р±Р°Р№Р»Р°РЅС‹СЃТ›Р°РЅ, СЃРѕРЅРґС‹Т›С‚Р°РЅ РјУ™СЂС‚РµР±РµРЅС– У™СЂ СЌРєСЂР°РЅРЅР°РЅ С–Р·РґРµСѓРґС–ТЈ Т›Р°Р¶РµС‚С– Р¶РѕТ›.',
      ),
      points: [
        DeskHelpGuidePoint(
          title: _t(
            ru: 'Р’С‹Р±РµСЂРёС‚Рµ РјРѕРґРµР»СЊ Рё РґРѕСЃС‚СѓРїРЅС‹Р№ СЂР°Р·РјРµСЂ',
            en: 'Pick a model and an available size',
            kk: 'РњРѕРґРµР»СЊ РјРµРЅ Т›РѕР»Р¶РµС‚С–РјРґС– У©Р»С€РµРјРґС– С‚Р°ТЈРґР°ТЈС‹Р·',
          ),
          description: _t(
            ru: 'Р’ РєР°СЂС‚РѕС‡РєРµ СЃСЂР°Р·Сѓ РІРёРґРЅРѕ, РєР°РєРёРµ СЂР°Р·РјРµСЂС‹ Р·Р°РєСЂС‹С‚С‹, Р° РєР°РєРёРµ РјРѕР¶РЅРѕ Р·Р°РєР°Р·Р°С‚СЊ Р±РµР· СѓС‚РѕС‡РЅРµРЅРёР№.',
            en: 'The product card immediately shows which sizes are unavailable and which ones can be ordered right away.',
            kk: 'РљР°СЂС‚РѕС‡РєР°РґР° Т›Р°Р№ У©Р»С€РµРј Р¶Р°Р±С‹Т› РµРєРµРЅС– Р¶У™РЅРµ Т›Р°Р№СЃС‹СЃС‹РЅ Р±С–СЂРґРµРЅ С‚Р°РїСЃС‹СЂС‹СЃ Р±РµСЂСѓРіРµ Р±РѕР»Р°С‚С‹РЅС‹ Р±С–СЂРґРµРЅ РєУ©СЂС–РЅРµРґС–.',
          ),
        ),
        DeskHelpGuidePoint(
          title: _t(
            ru: 'РЎР»РµРґРёС‚Рµ Р·Р° СЃС‚Р°С‚СѓСЃРѕРј Р±РµР· Р·РІРѕРЅРєРѕРІ',
            en: 'Track status without calls',
            kk: 'РњУ™СЂС‚РµР±РµРЅС– Т›РѕТЈС‹СЂР°СѓСЃС‹Р· Р±Р°Т›С‹Р»Р°ТЈС‹Р·',
          ),
          description: _t(
            ru: 'РџРѕСЃР»Рµ РѕРїР»Р°С‚С‹ Р·Р°РєР°Р· РїРµСЂРµС…РѕРґРёС‚ РІ С‚СЂРµРєРёРЅРі, РіРґРµ РІРёРґРЅС‹ СЌС‚Р°Рї, Р°РґСЂРµСЃ Рё РґРІРёР¶РµРЅРёРµ РїРѕ РґРѕСЃС‚Р°РІРєРµ.',
            en: 'After payment, the order moves into tracking where you can see the stage, address, and delivery movement.',
            kk: 'РўУ©Р»РµРјРЅРµРЅ РєРµР№С–РЅ С‚Р°РїСЃС‹СЂС‹СЃ Р±Р°Т›С‹Р»Р°СѓТ“Р° У©С‚РµРґС–, РѕРЅРґР° РєРµР·РµТЈ, РјРµРєРµРЅР¶Р°Р№ Р¶У™РЅРµ Р¶РµС‚РєС–Р·Сѓ Т›РѕР·Т“Р°Р»С‹СЃС‹ РєУ©СЂС–РЅРµРґС–.',
          ),
        ),
        DeskHelpGuidePoint(
          title: _t(
            ru: 'Р•СЃР»Рё РЅСѓР¶РЅРѕ РІРјРµС€Р°С‚РµР»СЊСЃС‚РІРѕ, РІСЃРµ РїРѕРґ СЂСѓРєРѕР№',
            en: 'If you need help, everything is ready',
            kk: 'РљУ©РјРµРє РєРµСЂРµРє Р±РѕР»СЃР°, Р±У™СЂС– РґР°Р№С‹РЅ',
          ),
          description: _t(
            ru: 'Р’РЅРёР·Сѓ РµСЃС‚СЊ Р±С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ: РјРѕР¶РЅРѕ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ email, РЅРѕРјРµСЂ Р·Р°РєР°Р·Р° Рё РіРѕС‚РѕРІС‹Р№ Р±СЂРёС„ РґР»СЏ РїРѕРґРґРµСЂР¶РєРё.',
            en: 'Below you will find quick actions to copy your email, order number, and a ready support brief.',
            kk: 'РўУ©РјРµРЅРґРµ email, С‚Р°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС– Р¶У™РЅРµ РґР°Р№С‹РЅ Т›РѕР»РґР°Сѓ РјУ™С‚С–РЅС–РЅ РєУ©С€С–СЂСѓРіРµ Р°СЂРЅР°Р»Т“Р°РЅ Р¶РµРґРµР» У™СЂРµРєРµС‚С‚РµСЂ Р±Р°СЂ.',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileFlowSection({required bool compact}) {
    return DeskHelpSystemFlowSection(
      compact: compact,
      eyebrow: _t(
        ru: 'РЎРРЎРўР•РњРќР«Р™ РџРћРўРћРљ',
        en: 'SYSTEM FLOW',
        kk: 'Р–Т®Р™Р•Р›Р†Рљ РђТ’Р«Рќ',
      ),
      steps: [
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.client, _language),
          details: _t(
            ru: 'РљР»РёРµРЅС‚ РІС‹Р±РёСЂР°РµС‚ РјРѕРґРµР»СЊ, РїСЂРѕРІРµСЂСЏРµС‚ РґРѕСЃС‚СѓРїРЅС‹Р№ СЂР°Р·РјРµСЂ, РїРѕРґС‚РІРµСЂР¶РґР°РµС‚ Р°РґСЂРµСЃ Рё РѕРїР»Р°С‡РёРІР°РµС‚ Р·Р°РєР°Р·.',
            en: 'The client chooses a model, checks the available size, confirms the address, and pays for the order.',
            kk: 'РљР»РёРµРЅС‚ РјРѕРґРµР»СЊРґС– С‚Р°ТЈРґР°Рї, Т›РѕР»Р¶РµС‚С–РјРґС– У©Р»С€РµРјРґС– С‚РµРєСЃРµСЂС–Рї, РјРµРєРµРЅР¶Р°Р№РґС‹ СЂР°СЃС‚Р°Рї, С‚Р°РїСЃС‹СЂС‹СЃС‚С‹ С‚У©Р»РµР№РґС–.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.franchisee, _language),
          details: _t(
            ru: 'Р¤СЂР°РЅС‡Р°Р№Р·Рё РїРѕР»СѓС‡Р°РµС‚ Р·Р°РєР°Р· СЃСЂР°Р·Сѓ РїРѕСЃР»Рµ РѕРїР»Р°С‚С‹, РїСЂРѕРІРµСЂСЏРµС‚ РґРµС‚Р°Р»Рё Рё РїРµСЂРµРґР°РµС‚ РµРіРѕ РІ СЂР°Р±РѕС‚Сѓ Р±РµР· Р»РёС€РЅРёС… РїРµСЂРµРїРёСЃРѕРє.',
            en: 'The franchisee receives the order right after payment, checks the details, and sends it into work without extra back-and-forth.',
            kk: 'Р¤СЂР°РЅС‡Р°Р№Р·Рё С‚Р°РїСЃС‹СЂС‹СЃС‚С‹ С‚У©Р»РµРјРЅРµРЅ РєРµР№С–РЅ Р±С–СЂРґРµРЅ Р°Р»С‹Рї, РґРµСЂРµРєС‚РµСЂРґС– С‚РµРєСЃРµСЂС–Рї, РѕРЅС‹ Р°СЂС‚С‹Т› С…Р°С‚ Р°Р»РјР°СЃСѓСЃС‹Р· Р¶Т±РјС‹СЃТ›Р° Р¶С–Р±РµСЂРµРґС–.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.production, _language),
          details: _t(
            ru: 'РџСЂРѕРёР·РІРѕРґСЃС‚РІРѕ РїСЂРёРЅРёРјР°РµС‚ Р·Р°РґР°С‡Сѓ, РѕР±РЅРѕРІР»СЏРµС‚ СЌС‚Р°РїС‹ РїРѕС€РёРІР° Рё РѕС‚РјРµС‡Р°РµС‚ РіРѕС‚РѕРІРЅРѕСЃС‚СЊ, РєРѕРіРґР° РІРµС‰СЊ СЃРѕР±СЂР°РЅР°.',
            en: 'Production accepts the task, updates tailoring stages, and marks the item ready once everything is complete.',
            kk: 'УЁРЅРґС–СЂС–СЃ С‚Р°РїСЃС‹СЂРјР°РЅС‹ Т›Р°Р±С‹Р»РґР°Рї, С‚С–РіСѓ РєРµР·РµТЈРґРµСЂС–РЅ Р¶Р°ТЈР°СЂС‚Р°РґС‹ Р¶У™РЅРµ Р±Т±Р№С‹Рј РґР°Р№С‹РЅ Р±РѕР»Т“Р°РЅРґР° РјУ™СЂС‚РµР±РµРЅС– Р±РµР»РіС–Р»РµР№РґС–.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.client, _language),
          details: _t(
            ru: 'РљР»РёРµРЅС‚ РІРёРґРёС‚ РѕР±РЅРѕРІР»РµРЅРёРµ РІ С‚СЂРµРєРёРЅРіРµ, РїРѕР»СѓС‡Р°РµС‚ РіРѕС‚РѕРІС‹Р№ СЃС‚Р°С‚СѓСЃ Рё Р·Р°РІРµСЂС€Р°РµС‚ С†РёРєР» РїРѕР»СѓС‡РµРЅРёРµРј Р·Р°РєР°Р·Р°.',
            en: 'The client sees the update in tracking, receives the ready status, and completes the cycle by receiving the order.',
            kk: 'РљР»РёРµРЅС‚ Р¶Р°ТЈР°СЂС‚СѓРґС‹ Р±Р°Т›С‹Р»Р°СѓРґР°РЅ РєУ©СЂРµРґС–, РґР°Р№С‹РЅ РјУ™СЂС‚РµР±РµСЃС–РЅ Р°Р»Р°РґС‹ Р¶У™РЅРµ С‚Р°РїСЃС‹СЂС‹СЃС‚С‹ Р°Р»Сѓ Р°СЂТ›С‹Р»С‹ С†РёРєР»РґС‹ Р°СЏТ›С‚Р°Р№РґС‹.',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSupportSection({
    required bool compact,
    required AppUser? user,
    required OrderModel? supportOrder,
  }) {
    return DeskHelpSupportSection(
      compact: compact,
      eyebrow: _t(
        ru: 'РџРћРњРћР©Р¬ Р РџРћР”Р”Р•Р Р–РљРђ',
        en: 'HELP & SUPPORT',
        kk: 'РљУЁРњР•Рљ Р–УРќР• ТљРћР›Р”РђРЈ',
      ),
      title: _t(
        ru: 'РџРѕРґРіРѕС‚РѕРІСЊС‚Рµ РѕР±СЂР°С‰РµРЅРёРµ Р·Р° РЅРµСЃРєРѕР»СЊРєРѕ СЃРµРєСѓРЅРґ.',
        en: 'Prepare a support message in a few seconds.',
        kk: 'ТљРѕР»РґР°Сѓ С…Р°Р±Р°СЂР»Р°РјР°СЃС‹РЅ Р±С–СЂРЅРµС€Рµ СЃРµРєСѓРЅРґС‚Р° РґР°Р№С‹РЅРґР°ТЈС‹Р·.',
      ),
      description: _t(
        ru: 'Р•СЃР»Рё РЅСѓР¶РЅРѕ Р±С‹СЃС‚СЂРѕ СЂРµС€РёС‚СЊ РІРѕРїСЂРѕСЃ РїРѕ Р°РґСЂРµСЃСѓ, РѕРїР»Р°С‚Рµ РёР»Рё Р·Р°РєР°Р·Сѓ, СЃРєРѕРїРёСЂСѓР№С‚Рµ РіРѕС‚РѕРІС‹Рµ РґР°РЅРЅС‹Рµ Рё РѕС‚РїСЂР°РІСЊС‚Рµ РёС… РІ РІР°С€ РєР°РЅР°Р» РїРѕРґРґРµСЂР¶РєРё AVISHU.',
        en: 'If you need to resolve an address, payment, or order issue quickly, copy the ready details and send them through your AVISHU support channel.',
        kk: 'Р•РіРµСЂ РјРµРєРµРЅР¶Р°Р№, С‚У©Р»РµРј РЅРµРјРµСЃРµ С‚Р°РїСЃС‹СЂС‹СЃ Р±РѕР№С‹РЅС€Р° СЃТ±СЂР°Т›С‚С‹ С‚РµР· С€РµС€Сѓ РєРµСЂРµРє Р±РѕР»СЃР°, РґР°Р№С‹РЅ РґРµСЂРµРєС‚РµСЂРґС– РєУ©С€С–СЂС–Рї, РѕР»Р°СЂРґС‹ AVISHU Т›РѕР»РґР°Сѓ Р°СЂРЅР°СЃС‹РЅР° Р¶С–Р±РµСЂС–ТЈС–Р·.',
      ),
      actions: [
        DeskHelpSupportAction(
          title: _t(
            ru: 'РЎРєРѕРїРёСЂРѕРІР°С‚СЊ СЃРѕРѕР±С‰РµРЅРёРµ РґР»СЏ С‡Р°С‚Р°',
            en: 'Copy chat message',
            kk: 'С‡Р°С‚С‚Р° Р¶С–Р±РµСЂСѓРіРµ Р°СЂРЅР°Р»Т“Р°РЅ С…Р°Р±Р°СЂР»Р°РјР°РЅС‹ РєУ©С€С–СЂСѓ',
          ),
          description: _t(
            ru: 'РћРґРЅРѕР№ РєРѕРїРёРµР№ РјРѕР¶РЅРѕ СЂР°Р·РѕРј РїРѕРґС‚СЏРЅСѓС‚СЊ email Рё РЅРѕРјРµСЂ Р·Р°РєР°Р·Р° РґР»СЏ С‡Р°С‚Р° РїРѕРґРґРµСЂР¶РєРё.',
            en: 'One copy action prepares a ready message for the support chat with your email and order number.',
            kk: 'Р‘С–СЂ РєУ©С€С–СЂСѓ Р°СЂТ›С‹Р»С‹ Рµmail РјРµРЅ С‚Р°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС– Р±Р°СЂ РґР°Р№С‹РЅ Т›РѕР»РґР°Сѓ С‡Р°С‚ С…Р°Р±Р°СЂР»Р°РјР°СЃС‹РЅ Р°Р»Р°СЃС‹Р·.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            _clientSupportBrief(
              userEmail: user?.email ?? '',
              order: supportOrder,
            ),
            _t(
              ru: 'РЎРѕРѕР±С‰РµРЅРёРµ РґР»СЏ С‡Р°С‚Р° СЃРєРѕРїРёСЂРѕРІР°РЅРѕ.',
              en: 'Chat message copied.',
              kk: 'С‡Р°С‚ С…Р°Р±Р°СЂР»Р°РјР°СЃС‹ РєУ©С€С–СЂС–Р»РґС–.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'РЎРєРѕРїРёСЂРѕРІР°С‚СЊ email РїСЂРѕС„РёР»СЏ',
            en: 'Copy profile email',
            kk: 'РџСЂРѕС„РёР»СЊ email-С‹РЅ РєУ©С€С–СЂСѓ',
          ),
          description: _t(
            ru: 'РџРѕР»РµР·РЅРѕ, РµСЃР»Рё РїРѕРґРґРµСЂР¶РєРµ РЅСѓР¶РЅРѕ Р±С‹СЃС‚СЂРѕ РЅР°Р№С‚Рё РІР°С€ Р°РєРєР°СѓРЅС‚.',
            en: 'Useful when support needs to find your account quickly.',
            kk: 'ТљРѕР»РґР°Сѓ Т›С‹Р·РјРµС‚С–РЅРµ Р°РєРєР°СѓРЅС‚С‹ТЈС‹Р·РґС‹ С‚РµР· С‚Р°Р±Сѓ РєРµСЂРµРє Р±РѕР»СЃР° РїР°Р№РґР°Р»С‹.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            user?.email ?? '',
            _t(
              ru: 'Email РїСЂРѕС„РёР»СЏ СЃРєРѕРїРёСЂРѕРІР°РЅ.',
              en: 'Profile email copied.',
              kk: 'РџСЂРѕС„РёР»СЊ email-С‹ РєУ©С€С–СЂС–Р»РґС–.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'РЎРєРѕРїРёСЂРѕРІР°С‚СЊ РЅРѕРјРµСЂ Р·Р°РєР°Р·Р°',
            en: 'Copy order number',
            kk: 'РўР°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС–РЅ РєУ©С€С–СЂСѓ',
          ),
          description: _t(
            ru: 'Р”РѕР±Р°РІСЊС‚Рµ РЅРѕРјРµСЂ Р·Р°РєР°Р·Р° РІ СЃРѕРѕР±С‰РµРЅРёРµ, С‡С‚РѕР±С‹ РЅРµ С‚СЂР°С‚РёС‚СЊ РІСЂРµРјСЏ РЅР° СѓС‚РѕС‡РЅРµРЅРёРµ.',
            en: 'Add the order number to your message so there is no delay in identifying the request.',
            kk: 'РҐР°Р±Р°СЂР»Р°РјР°Т“Р° С‚Р°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС–РЅ Т›РѕСЃС‹ТЈС‹Р·, СЃРѕРЅРґР° СЃТ±СЂР°СѓРґС‹ Р°РЅС‹Т›С‚Р°СѓТ“Р° СѓР°Т›С‹С‚ РєРµС‚РїРµР№РґС–.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            supportOrder == null ? '' : '#${supportOrder.shortId}',
            _t(
              ru: 'РќРѕРјРµСЂ Р·Р°РєР°Р·Р° СЃРєРѕРїРёСЂРѕРІР°РЅ.',
              en: 'Order number copied.',
              kk: 'РўР°РїСЃС‹СЂС‹СЃ РЅУ©РјС–СЂС– РєУ©С€С–СЂС–Р»РґС–.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'РЎРєРѕРїРёСЂРѕРІР°С‚СЊ Р±СЂРёС„ РґР»СЏ РїРѕРґРґРµСЂР¶РєРё',
            en: 'Copy support brief',
            kk: 'ТљРѕР»РґР°Сѓ РјУ™С‚С–РЅС–РЅ РєУ©С€С–СЂСѓ',
          ),
          description: _t(
            ru: 'Р“РѕС‚РѕРІС‹Р№ С€Р°Р±Р»РѕРЅ РѕР±СЂР°С‰РµРЅРёСЏ СѓР¶Рµ СЃРѕРґРµСЂР¶РёС‚ Р°РєРєР°СѓРЅС‚ Рё Р·Р°РєР°Р·, С‡С‚РѕР±С‹ РІР°Рј РѕСЃС‚Р°Р»РѕСЃСЊ РѕРїРёСЃР°С‚СЊ С‚РѕР»СЊРєРѕ СЃР°РјСѓ СЃРёС‚СѓР°С†РёСЋ.',
            en: 'The ready template already includes your account and order, so you only need to describe the issue itself.',
            kk: 'Р”Р°Р№С‹РЅ С€Р°Р±Р»РѕРЅРґР° Р°РєРєР°СѓРЅС‚ РїРµРЅ С‚Р°РїСЃС‹СЂС‹СЃ Р±Р°СЂ, СЃРѕРЅРґС‹Т›С‚Р°РЅ СЃС–Р·РіРµ С‚РµРє РјУ™СЃРµР»РµРЅС–ТЈ У©Р·С–РЅ СЃРёРїР°С‚С‚Р°Сѓ Т›Р°Р»Р°РґС‹.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            _clientSupportBrief(
              userEmail: user?.email ?? '',
              order: supportOrder,
            ),
            _t(
              ru: 'Р‘СЂРёС„ РґР»СЏ РїРѕРґРґРµСЂР¶РєРё СЃРєРѕРїРёСЂРѕРІР°РЅ.',
              en: 'Support brief copied.',
              kk: 'ТљРѕР»РґР°Сѓ РјУ™С‚С–РЅС– РєУ©С€С–СЂС–Р»РґС–.',
            ),
          ),
        ),
      ],
      footerText: _t(
        ru: 'Р§С‚РѕР±С‹ РїРѕР»СѓС‡РёС‚СЊ РѕС‚РІРµС‚ Р±С‹СЃС‚СЂРµРµ, РґРѕР±Р°РІСЊС‚Рµ РІ РѕР±СЂР°С‰РµРЅРёРµ СЂР°Р·РјРµСЂ, Р°РґСЂРµСЃ РґРѕСЃС‚Р°РІРєРё Рё СЃРєСЂРёРЅ, РµСЃР»Рё С‡С‚Рѕ-С‚Рѕ РѕС‚РѕР±СЂР°Р¶Р°РµС‚СЃСЏ РЅРµРІРµСЂРЅРѕ.',
        en: 'To get help faster, include your size, delivery address, and a screenshot if something looks wrong.',
        kk: 'Р–Р°СѓР°РїС‚С‹ С‚РµР·С–СЂРµРє Р°Р»Сѓ ТЇС€С–РЅ У©Р»С€РµРјРґС–, Р¶РµС‚РєС–Р·Сѓ РјРµРєРµРЅР¶Р°Р№С‹РЅ Р¶У™РЅРµ Р±С–СЂРґРµТЈРµ Т›Р°С‚Рµ РєУ©СЂС–РЅСЃРµ СЃРєСЂРёРЅС€РѕС‚С‚С‹ Т›РѕСЃС‹ТЈС‹Р·.',
      ),
    );
  }

  Widget _buildProductScreen() {
    final product = _selectedProduct!;
    final selectedColor = _selectedColor ?? product.defaultColor;
    final selectedSize = _resolvedSelectedSize(product);
    final canOrderProduct = _canOrderProduct(product);
    final isFavorite = _favoriteProductIds.contains(product.id);
    final categoryLabel = localizeCatalogSection(_language, product.category);
    final seasonLabel = localizeCatalogSection(_language, product.season);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t(ru: 'ГЛАВНАЯ', en: 'HOME', kk: 'БАСТЫ БЕТ')} / ${seasonLabel.toUpperCase()} / ${categoryLabel.toUpperCase()} / ${product.title}',
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
          title: _t(
            ru: 'ИНФОРМАЦИЯ О ТОВАРЕ',
            en: 'PRODUCT INFO',
            kk: 'ТАУАР ТУРАЛЫ АҚПАРАТ',
          ),
          rows: [
            OrderInfoRowData(
              label: _t(ru: 'Артикул', en: 'SKU', kk: 'Артикул'),
              value: product.sku,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Материал', en: 'Material', kk: 'Материал'),
              value: product.material,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Силуэт', en: 'Silhouette', kk: 'Силуэт'),
              value: product.silhouette,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Цвет', en: 'Color', kk: 'Түс'),
              value: selectedColor,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Размер', en: 'Size', kk: 'Өлшем'),
              value: _selectedSizeLabel(product),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(ru: 'ЦВЕТ', en: 'COLOR', kk: 'ТҮС'),
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
                _t(ru: 'РАЗМЕР', en: 'SIZE', kk: 'ӨЛШЕМ'),
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
                        enabled: product.isSizeAvailable(size),
                        onTap: () => setState(() => _selectedSize = size),
                      ),
                    )
                    .toList(),
              ),
              if (!product.hasAvailableSizes ||
                  product.unavailableSizeCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  _unavailableSizeMessage(product),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: _showSizeGuideSheet,
                child: Row(
                  children: [
                    const Icon(Icons.straighten, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _t(
                        ru: 'Размерная сетка',
                        en: 'Size Guide',
                        kk: 'Өлшемдер кестесі',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (product.preorder) ...[
                const SizedBox(height: 16),
                Text(
                  _t(
                    ru: 'ДАТА ГОТОВНОСТИ',
                    en: 'READY DATE',
                    kk: 'ДАЙЫН БОЛАТЫН КҮНІ',
                  ),
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
                    ? _t(ru: 'В наличии', en: 'In Stock', kk: 'Қоймада бар')
                    : _t(
                        ru: 'Нет в наличии',
                        en: 'Out of Stock',
                        kk: 'Қоймада жоқ',
                      ),
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
                  Flexible(
                    flex: 4,
                    child: SizedBox(height: 56, child: _quantitySelector()),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 6,
                    child: SizedBox(
                      height: 56,
                      child: AvishuButton(
                        text: isFavorite
                            ? _t(
                                ru: 'В ИЗБРАННОМ',
                                en: 'IN FAVORITES',
                                kk: 'ТАҢДАУЛЫДА',
                              )
                            : _t(
                                ru: 'В ИЗБРАННОЕ',
                                en: 'ADD TO FAVORITES',
                                kk: 'ТАҢДАУЛЫҒА ҚОСУ',
                              ),
                        expanded: true,
                        height: 56,
                        variant: AvishuButtonVariant.outline,
                        icon: isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border_outlined,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        onPressed: () {
                          setState(() => _toggleFavorite(product.id));
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AvishuButton(
                text: product.preorder
                    ? _t(
                        ru: 'ПРОДОЛЖИТЬ ПРЕДЗАКАЗ',
                        en: 'CONTINUE PREORDER',
                        kk: 'АЛДЫН АЛА ТАПСЫРЫСТЫ ЖАЛҒАСТЫРУ',
                      )
                    : _t(
                        ru: 'ОФОРМИТЬ ЗАКАЗ',
                        en: 'PLACE ORDER',
                        kk: 'ТАПСЫРЫС БЕРУ',
                      ),
                expanded: true,
                variant: AvishuButtonVariant.filled,
                onPressed: canOrderProduct
                    ? () {
                        setState(() {
                          _view = ClientView.checkout;
                          _deliveryMethod = DeliveryMethod.courier;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _productAccordion(
          title: _t(ru: 'ОПИСАНИЕ', en: 'DESCRIPTION', kk: 'СИПАТТАМА'),
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
          title: _t(
            ru: 'ХАРАКТЕРИСТИКИ',
            en: 'SPECIFICATIONS',
            kk: 'СИПАТТАМАЛАР',
          ),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
          title: _t(ru: 'УХОД', en: 'CARE', kk: 'КҮТІМ'),
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
                      'вЂў $rule',
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
    final profile = ref.watch(currentUserProfileProvider).value;
    final currentUserId = ref.watch(currentUserProvider).value?.uid ?? '';
    final compactCards = ref.watch(appSettingsProvider).compactCards;
    final orders = currentUserId.isEmpty
        ? const <OrderModel>[]
        : (ref.watch(clientOrdersProvider(currentUserId)).value ??
              const <OrderModel>[]);
    final loyalty = _loyaltySnapshot(profile, orders);
    final pricing = _checkoutPricing(product, profile: profile, orders: orders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientCheckoutSummarySection(
          title: _t(
            ru: 'СОСТАВ ЗАКАЗА',
            en: 'ORDER SUMMARY',
            kk: 'ТАПСЫРЫС ҚҰРАМЫ',
          ),
          rows: [
            OrderInfoRowData(
              label: _t(ru: 'Изделие', en: 'Product', kk: 'Бұйым'),
              value: product.title,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Цвет', en: 'Color', kk: 'Түс'),
              value: _selectedColor ?? product.defaultColor,
            ),
            OrderInfoRowData(
              label: _t(ru: 'Размер', en: 'Size', kk: 'Өлшем'),
              value: _selectedSizeLabel(product),
            ),
            OrderInfoRowData(
              label: _t(ru: 'Количество', en: 'Quantity', kk: 'Саны'),
              value: '$_quantity',
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Стоимость позиции',
                en: 'Unit Price',
                kk: 'Бірлік бағасы',
              ),
              value: formatCurrency(product.price),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClientCheckoutAddressSection(
          compact: compactCards,
          title: _checkoutAddressTitle(),
          presetChips: _deliveryAddressPresets
              .map((preset) => _addressPresetChip(preset))
              .toList(),
          cityController: _cityController,
          addressController: _addressController,
          apartmentController: _apartmentController,
          noteController: _noteController,
          cityLabel: _checkoutCityLabel(),
          addressLabel: _checkoutAddressLabel(),
          apartmentLabel: _checkoutApartmentLabel(),
          noteLabel: _checkoutCommentLabel(),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: Listenable.merge([
            _cityController,
            _addressController,
            _apartmentController,
          ]),
          builder: (context, _) => _buildCheckoutDeliveryMapCard(product),
        ),
        const SizedBox(height: 12),
        ClientCheckoutLoyaltySection(
          compact: compactCards,
          title: _checkoutLoyaltyTitle(),
          summary:
              '${loyalty.currentTier.titleFor(_language)} / ${loyalty.currentTier.perksFor(_language)}',
          isDiscountApplied: _applyLoyaltyDiscount,
          canApplyDiscount: loyalty.currentTier.discountRate > 0,
          onDiscountChanged: (value) {
            setState(() => _applyLoyaltyDiscount = value);
          },
          discountTitle: _checkoutDiscountTitle(),
          discountSubtitle: _checkoutDiscountSubtitle(loyalty),
          isBonusApplied: _useBonusBalance,
          canUseBonus: loyalty.bonusBalance > 0,
          onBonusChanged: (value) {
            setState(() => _useBonusBalance = value);
          },
          bonusTitle: _checkoutBonusTitle(),
          bonusSubtitle: _checkoutBonusSubtitle(loyalty),
        ),
        const SizedBox(height: 12),
        ClientCheckoutMethodSection(
          title: _checkoutMethodTitle(),
          methodLabel: _checkoutMethodLabel(),
          courierLabel: DeliveryMethod.courier.labelFor(_language),
          isCourierActive: _deliveryMethod == DeliveryMethod.courier,
          onCourierTap: () {
            setState(() => _deliveryMethod = DeliveryMethod.courier);
          },
          pickupLabel: DeliveryMethod.pickup.labelFor(_language),
          isPickupActive: _deliveryMethod == DeliveryMethod.pickup,
          onPickupTap: () {
            setState(() => _deliveryMethod = DeliveryMethod.pickup);
          },
        ),
        const SizedBox(height: 12),
        ClientCheckoutTotalSection(
          title: _t(ru: 'ИТОГО', en: 'TOTAL', kk: 'ЖИЫНЫ'),
          rows: _checkoutRows(product, pricing: pricing, loyalty: loyalty),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: _t(
            ru: 'ПЕРЕЙТИ К ОПЛАТЕ',
            en: 'GO TO PAYMENT',
            kk: 'ТӨЛЕМГЕ ӨТУ',
          ),
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
    final profile = ref.watch(currentUserProfileProvider).value;
    final compactCards = ref.watch(appSettingsProvider).compactCards;
    final orders =
        ref.watch(clientOrdersProvider(clientId)).value ?? const <OrderModel>[];
    final loyalty = _loyaltySnapshot(profile, orders);
    final pricing = _checkoutPricing(product, profile: profile, orders: orders);

    return ClientPaymentSection(
      compact: compactCards,
      formTitle: _paymentFormTitle(),
      cardController: _cardController,
      cardNumberLabel: _paymentCardNumberLabel(),
      expiryController: _expiryController,
      expiryLabel: 'MM / YY',
      cvvController: _cvvController,
      cvvLabel: 'CVV',
      detailsTitle: _paymentDetailsTitle(),
      detailsRows: _checkoutRows(product, pricing: pricing, loyalty: loyalty),
      submitLabel: _paymentSubmitLabel(),
      isSubmitting: _isSubmitting,
      onSubmit: () => _submitOrder(clientId),
    );
  }

  Widget _buildTrackingScreen(OrderModel? order, {String? clientDisplayName}) {
    final compactCards = ref.watch(appSettingsProvider).compactCards;
    if (order == null) {
      return ClientTrackingEmptyStateCard(
        compact: compactCards,
        message: _trackingWaitingMessage(),
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
        ClientTrackingStatusSection(
          compact: compactCards,
          orderLabel: _trackingOrderHeading(order),
          productName: order.productName,
          roleDescription: order.status.roleDescriptionFor(_language),
          status: order.status,
          statusLine: _trackingStatusLine(order),
        ),
        const SizedBox(height: 12),
        _buildTrackingDeliveryMapCard(order),
        const SizedBox(height: 12),
        ClientTrackingDetailsSection(
          title: _trackingDetailsTitle(),
          rows: OrderSummaryRows.forOrder(order, language: _language),
        ),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ClientTrackingNoteCard(
            title: _trackingClientCommentTitle(),
            label: _trackingCommentLabel(),
            value: order.clientNote,
          ),
        ],
        if (order.franchiseeNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ClientTrackingNoteCard(
            title: _trackingFranchiseNoteTitle(),
            label: _trackingStatusFieldLabel(),
            value: order.franchiseeNote,
          ),
        ],
        if (order.productionNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ClientTrackingNoteCard(
            title: _trackingFactoryNoteTitle(),
            label: _trackingFactoryLabel(),
            value: order.productionNote,
          ),
        ],
        const SizedBox(height: 12),
        ClientTrackingActionsRow(
          backLabel: _trackingBackLabel(),
          onBack: () {
            setState(() {
              _tab = ClientTab.dashboard;
              _view = ClientView.root;
            });
          },
          catalogLabel: _trackingCatalogLabel(),
          onOpenCatalog: () {
            setState(() {
              _tab = ClientTab.collections;
              _view = ClientView.root;
            });
          },
        ),
      ],
    );
  }

  Future<void> _submitOrder(String clientId) async {
    if (_isSubmitting) return;
    final product = _selectedProduct!;
    final selectedSize = _resolvedSelectedSize(product);
    final profile = ref.read(currentUserProfileProvider).value;
    final orders =
        ref.read(clientOrdersProvider(clientId)).value ?? const <OrderModel>[];
    final pricing = _checkoutPricing(product, profile: profile, orders: orders);
    if (!_validateCheckoutFields() || !_validatePaymentFields()) {
      return;
    }
    if (selectedSize.isEmpty) {
      _showMessage(_unavailableSizeMessage(product));
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
            sizeLabel: selectedSize,
            quantity: _quantity,
            unitPrice: product.price,
            imageUrl: product.imageUrls.first,
            currency: 'KZT',
            amount: pricing.total,
            isPreorder: product.preorder,
            readyBy: product.preorder ? _selectedDate : null,
            deliveryMethod: _deliveryMethod,
            deliveryCity: _cityController.text.trim(),
            deliveryAddress: _addressController.text.trim(),
            apartment: _apartmentController.text.trim(),
            paymentLast4: _cardLast4,
            clientNote: _composeOrderNote(product),
            loyaltyBonusRedeemed: pricing.bonusRedeemed,
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
          kk: 'Қала мен жеткізу мекенжайын толтырыңыз.',
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
          kk: 'Банк картасының деректерін тексеріңіз.',
        ),
      );
      return false;
    }
    return true;
  }

  String _checkoutAddressTitle() {
    return _t(ru: 'Адрес доставки', en: 'DELIVERY ADDRESS');
  }

  String _checkoutCityLabel() {
    return _t(ru: 'Город', en: 'City');
  }

  String _checkoutAddressLabel() {
    return _t(ru: 'Адрес', en: 'Address');
  }

  String _checkoutApartmentLabel() {
    return _t(ru: 'Квартира / офис', en: 'Apartment / Office');
  }

  String _checkoutCommentLabel() {
    return _t(ru: 'Комментарий к заказу', en: 'Order Comment');
  }

  String _checkoutLoyaltyTitle() {
    return _t(ru: 'Преимущества лояльности', en: 'LOYALTY BENEFITS');
  }

  String _checkoutDiscountTitle() {
    return _t(ru: 'Применить скидку уровня', en: 'Apply tier discount');
  }

  String _checkoutDiscountSubtitle(LoyaltyProfileSnapshot loyalty) {
    return _t(
      ru: 'Сейчас доступно ${_discountLabel(loyalty.currentTier.discountRate)} на этот заказ.',
      en: '${_discountLabel(loyalty.currentTier.discountRate)} is available for this order.',
    );
  }

  String _checkoutBonusTitle() {
    return _t(ru: 'Использовать бонусный баланс', en: 'Use bonus balance');
  }

  String _checkoutBonusSubtitle(LoyaltyProfileSnapshot loyalty) {
    return _t(
      ru: 'Доступно ${formatCurrency(loyalty.bonusBalance)} для оплаты.',
      en: '${formatCurrency(loyalty.bonusBalance)} can be applied to the payment.',
    );
  }

  String _checkoutMethodTitle() {
    return _t(ru: 'Способ получения', en: 'FULFILLMENT METHOD');
  }

  String _checkoutMethodLabel() {
    return _t(ru: 'Способ', en: 'METHOD');
  }

  String _paymentFormTitle() {
    return _t(
      ru: '\u041e\u043f\u043b\u0430\u0442\u0430 \u043a\u0430\u0440\u0442\u043e\u0439',
      en: 'CARD PAYMENT',
    );
  }

  String _paymentCardNumberLabel() {
    return _t(
      ru: '\u041d\u043e\u043c\u0435\u0440 \u043a\u0430\u0440\u0442\u044b',
      en: 'Card Number',
    );
  }

  String _paymentDetailsTitle() {
    return _t(
      ru: '\u0414\u0435\u0442\u0430\u043b\u0438 \u043e\u043f\u043b\u0430\u0442\u044b',
      en: 'PAYMENT DETAILS',
    );
  }

  String _paymentSubmitLabel() {
    return _t(
      ru: '\u041e\u043f\u043b\u0430\u0442\u0438\u0442\u044c',
      en: 'PAY',
    );
  }

  String _trackingWaitingMessage() {
    return _t(
      ru: 'Ждём синхронизацию заказа.',
      en: 'Waiting for order synchronization.',
    );
  }

  String _trackingOrderHeading(OrderModel order) {
    return '${_t(ru: 'Заказ', en: 'ORDER')} #${order.shortId}';
  }

  String _trackingStatusLine(OrderModel order) {
    return '${_t(ru: 'Статус', en: 'STATUS')} / ${order.status.clientLabelFor(_language)}';
  }

  String _trackingDetailsTitle() {
    return _t(ru: 'Детали заказа', en: 'ORDER DETAILS');
  }

  String _trackingClientCommentTitle() {
    return _t(ru: 'Комментарий клиента', en: 'CLIENT COMMENT');
  }

  String _trackingCommentLabel() {
    return _t(ru: 'Комментарий', en: 'Comment');
  }

  String _trackingFranchiseNoteTitle() {
    return _t(ru: 'Комментарий франшизы', en: 'FRANCHISE NOTE');
  }

  String _trackingStatusFieldLabel() {
    return _t(ru: 'Статус', en: 'Status');
  }

  String _trackingFactoryNoteTitle() {
    return _t(ru: 'Комментарий производства', en: 'FACTORY NOTE');
  }

  String _trackingFactoryLabel() {
    return _t(ru: 'Производство', en: 'Factory');
  }

  String _trackingBackLabel() {
    return _t(ru: 'Назад', en: 'BACK');
  }

  String _trackingCatalogLabel() {
    return _t(ru: 'Каталог', en: 'CATALOG');
  }

  void _applyCatalogSource(List<CatalogProduct> products) {
    if (products.isEmpty) {
      return;
    }

    _catalogProducts = products;

    final minPrice = _priceFilterMin;
    final maxPrice = _snappedCatalogMaxPrice;
    if (_priceRange.start < minPrice ||
        _priceRange.end > maxPrice ||
        _priceRange.start > _priceRange.end) {
      _priceRange = _normalizePriceRange(RangeValues(minPrice, maxPrice));
    }

    if (_selectedProduct != null) {
      for (final product in _catalogProducts) {
        if (product.id == _selectedProduct!.id) {
          _selectedProduct = product;
          if (_selectedSize == null ||
              !product.isSizeAvailable(_selectedSize!)) {
            _selectedSize = _preferredSizeFor(product);
          }
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

  Future<void> _copyToClipboard(String text, String message) async {
    if (text.trim().isEmpty) {
      _showMessage(
        _t(
          ru: 'Пока нечего копировать.',
          en: 'There is nothing to copy yet.',
          kk: 'Әзірге көшіретін дерек жоқ.',
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showMessage(message);
  }

  String _clientSupportBrief({
    required String userEmail,
    required OrderModel? order,
  }) {
    final accountEmail = userEmail.trim().isEmpty
        ? 'not_provided'
        : userEmail.trim();
    final orderLabel = order == null ? 'not_attached' : '#${order.shortId}';

    return [
      'AVISHU SUPPORT BRIEF',
      'ROLE: CLIENT',
      'ACCOUNT: $accountEmail',
      'ORDER: $orderLabel',
      'ISSUE:',
      '- What happened',
      '- What you expected instead',
      '- Screenshot attached: yes / no',
    ].join('\n');
  }

  void _openProduct(CatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _selectedDate = product.preorder ? dateOptions[1] : null;
      _selectedColor = product.defaultColor;
      _selectedSize = _preferredSizeFor(product);
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
      unawaited(_saveFavoriteProductIds());
      return;
    }
    _favoriteProductIds.add(productId);
    unawaited(_saveFavoriteProductIds());
  }

  Future<void> _loadFavoriteProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs.getStringList(_favoriteProductIdsKey) ?? const <String>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteProductIds
        ..clear()
        ..addAll(storedIds);
    });
  }

  Future<void> _saveFavoriteProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteProductIdsKey,
      _favoriteProductIds.toList()..sort(),
    );
  }

  double _snapPriceToStep(double value, {bool roundUp = false}) {
    final ratio = value / _priceFilterStep;
    final snappedSteps = roundUp ? ratio.ceil() : ratio.round();
    return snappedSteps * _priceFilterStep;
  }

  RangeValues _normalizePriceRange(RangeValues values) {
    final start = _snapPriceToStep(
      values.start,
    ).clamp(_priceFilterMin, _snappedCatalogMaxPrice);
    final end = _snapPriceToStep(
      values.end,
    ).clamp(_priceFilterMin, _snappedCatalogMaxPrice);
    return RangeValues(start <= end ? start : end, end >= start ? end : start);
  }

  String? _preferredSizeFor(CatalogProduct product) {
    if (product.isSizeAvailable(product.defaultSize)) {
      return product.defaultSize;
    }
    if (product.firstAvailableSize.isNotEmpty) {
      return product.firstAvailableSize;
    }
    return null;
  }

  String _resolvedSelectedSize(CatalogProduct product) {
    final selectedSize = _selectedSize;
    if (selectedSize != null && product.isSizeAvailable(selectedSize)) {
      return selectedSize;
    }
    return _preferredSizeFor(product) ?? '';
  }

  bool _canOrderProduct(CatalogProduct product) {
    return _resolvedSelectedSize(product).isNotEmpty;
  }

  String _catalogSizeChipLabel(CatalogProduct product) {
    final firstAvailableSize = product.firstAvailableSize;
    if (firstAvailableSize.isNotEmpty) {
      return firstAvailableSize;
    }
    return _t(ru: 'Размер закрыт', en: 'Size Closed', kk: 'Өлшем жабық');
  }

  String _selectedSizeLabel(CatalogProduct product) {
    final selectedSize = _resolvedSelectedSize(product);
    if (selectedSize.isNotEmpty) {
      return selectedSize;
    }
    return _t(ru: 'Недоступно', en: 'Unavailable', kk: 'Қолжетімсіз');
  }

  String _unavailableSizeMessage(CatalogProduct product) {
    if (!product.hasAvailableSizes) {
      return _t(
        ru: 'Сейчас нет доступных размеров. Проверьте позже или выберите другую модель.',
        en: 'There are no available sizes right now. Check back later or choose another model.',
        kk: 'Қазір қолжетімді өлшем жоқ. Кейінірек қайта тексеріңіз немесе басқа модельді таңдаңыз.',
      );
    }
    final unavailableSizes = product.sizes
        .where((size) => !product.isSizeAvailable(size))
        .toList();
    final sizeList = unavailableSizes.join(', ');
    return _t(
      ru: 'Сейчас недоступны размеры: $sizeList',
      en: 'Currently unavailable sizes: $sizeList',
      kk: 'Қазір қолжетімсіз өлшемдер: $sizeList',
    );
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
    _priceRange = RangeValues(_priceFilterMin, _snappedCatalogMaxPrice);
  }

  String get _cardLast4 {
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  LoyaltyProfileSnapshot _loyaltySnapshot(
    UserProfile? profile,
    List<OrderModel> orders,
  ) {
    final totalSpent =
        profile?.loyaltyTotalSpent ?? _fallbackLoyaltySpend(orders);
    final bonusBalance =
        profile?.loyaltyBonusBalance ??
        (profile?.loyaltyPoints.toDouble() ?? 0.0);
    return LoyaltyProgram.profileSnapshot(
      totalSpent: totalSpent,
      bonusBalance: bonusBalance,
    );
  }

  LoyaltyCheckoutPricing _checkoutPricing(
    CatalogProduct product, {
    UserProfile? profile,
    List<OrderModel> orders = const <OrderModel>[],
  }) {
    final loyalty = _loyaltySnapshot(profile, orders);
    return LoyaltyProgram.pricing(
      subtotal: product.price * _quantity,
      deliveryMethod: _deliveryMethod,
      totalSpent: loyalty.totalSpent,
      bonusBalance: loyalty.bonusBalance,
      applyTierDiscount: _applyLoyaltyDiscount,
      useBonusBalance: _useBonusBalance,
    );
  }

  double _fallbackLoyaltySpend(List<OrderModel> orders) {
    return orders.fold<double>(0, (total, order) => total + order.totalAmount);
  }

  double _totalPrice(CatalogProduct product) {
    final profile = ref.read(currentUserProfileProvider).value;
    final orders =
        ref
            .read(
              clientOrdersProvider(
                ref.read(currentUserProvider).value?.uid ?? '',
              ),
            )
            .value ??
        const <OrderModel>[];
    return _checkoutPricing(product, profile: profile, orders: orders).total;
  }

  String _discountLabel(double rate) {
    return '${(rate * 100).round()}%';
  }

  String _composeOrderNote(CatalogProduct product) {
    final customerNote = _noteController.text.trim();
    final profile = ref.read(currentUserProfileProvider).value;
    final currentUserId = ref.read(currentUserProvider).value?.uid ?? '';
    final orders = currentUserId.isEmpty
        ? const <OrderModel>[]
        : (ref.read(clientOrdersProvider(currentUserId)).value ??
              const <OrderModel>[]);
    final pricing = _checkoutPricing(product, profile: profile, orders: orders);
    final lines = <String>[
      '${_t(ru: 'Цвет', en: 'Color')}: ${_selectedColor ?? product.defaultColor}',
      '${_t(ru: 'Количество', en: 'Quantity')}: $_quantity',
      if (pricing.discountAmount > 0)
        '${_t(ru: 'Скидка лояльности', en: 'Loyalty discount', kk: 'Адалдық жеңілдігі')}: ${formatCurrency(pricing.discountAmount)}',
      if (pricing.bonusRedeemed > 0)
        '${_t(ru: 'Списано бонусов', en: 'Bonuses used', kk: 'Пайдаланылған бонус')}: ${formatCurrency(pricing.bonusRedeemed)}',
      if (pricing.earnedBonus > 0)
        '${_t(ru: 'Начислится бонусами', en: 'Bonuses to earn', kk: 'Түсетін бонус')}: ${formatCurrency(pricing.earnedBonus)}',
      if (customerNote.isNotEmpty)
        '${_t(ru: 'Комментарий клиента', en: 'Client Comment', kk: 'Клиент пікірі')}: $customerNote',
    ];
    return lines.join('\n');
  }

  List<OrderInfoRowData> _checkoutRows(
    CatalogProduct product, {
    required LoyaltyCheckoutPricing pricing,
    required LoyaltyProfileSnapshot loyalty,
  }) {
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
        value: _selectedSizeLabel(product),
      ),
      OrderInfoRowData(
        label: _t(ru: 'Количество', en: 'Quantity'),
        value: '$_quantity',
      ),
      OrderInfoRowData(
        label: _t(ru: 'Стоимость', en: 'Subtotal'),
        value: formatCurrency(pricing.subtotal),
      ),
      OrderInfoRowData(
        label: _t(ru: 'Доставка', en: 'Delivery'),
        value:
            '${_deliveryMethod.labelFor(_language)} / ${formatCurrency(pricing.deliveryFee)}',
      ),
      if (pricing.courierSavings > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Экономия на доставке',
            en: 'Courier savings',
            kk: 'Жеткізу үнемі',
          ),
          value: '- ${formatCurrency(pricing.courierSavings)}',
        ),
      if (pricing.discountAmount > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Скидка уровня',
            en: 'Tier discount',
            kk: 'Деңгей жеңілдігі',
          ),
          value: '- ${formatCurrency(pricing.discountAmount)}',
        ),
      if (pricing.bonusRedeemed > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Списано бонусов',
            en: 'Bonuses used',
            kk: 'Пайдаланылған бонус',
          ),
          value: '- ${formatCurrency(pricing.bonusRedeemed)}',
        ),
      if (product.preorder && _selectedDate != null)
        OrderInfoRowData(
          label: _t(ru: 'Дата готовности', en: 'Ready Date'),
          value: formatDate(_selectedDate!),
        ),
      if (pricing.earnedBonus > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Вернется бонусами',
            en: 'Bonuses to earn',
            kk: 'Бонуспен қайтады',
          ),
          value: formatCurrency(pricing.earnedBonus),
        ),
      OrderInfoRowData(
        label: _t(ru: 'Итого', en: 'Total', kk: 'Жиыны'),
        value: formatCurrency(pricing.total),
      ),
    ];
  }

  List<_DeliveryAddressPreset> get _deliveryAddressPresets =>
      const <_DeliveryAddressPreset>[
        _DeliveryAddressPreset(
          labelRu: 'Дом / Достык',
          labelEn: 'Home / Dostyk',
          labelKk: 'Үй / Достық',
          city: 'Алматы',
          address: 'пр. Достык, 25',
          apartment: '12',
        ),
        _DeliveryAddressPreset(
          labelRu: 'Esentai',
          labelEn: 'Esentai',
          labelKk: 'Esentai',
          city: 'Алматы',
          address: 'Esentai Mall',
          apartment: 'Boutique',
        ),
        _DeliveryAddressPreset(
          labelRu: 'Mega Alma-Ata',
          labelEn: 'Mega Alma-Ata',
          labelKk: 'Mega Alma-Ata',
          city: 'Алматы',
          address: 'ул. Розыбакиева, 247А',
          apartment: '1',
        ),
      ];

  Widget _addressPresetChip(_DeliveryAddressPreset preset) {
    final isActive =
        _cityController.text.trim() == preset.city &&
        _addressController.text.trim() == preset.address &&
        _apartmentController.text.trim() == preset.apartment;

    return InkWell(
      onTap: () => _applyAddressPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Text(
          _language == AppLanguage.russian
              ? preset.labelRu
              : _language == AppLanguage.kazakh
              ? preset.labelKk
              : preset.labelEn,
          style: AppTypography.eyebrow.copyWith(
            color: isActive ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }

  void _applyAddressPreset(_DeliveryAddressPreset preset) {
    setState(() {
      _cityController.text = preset.city;
      _addressController.text = preset.address;
      _apartmentController.text = preset.apartment;
    });
  }

  Widget _buildCheckoutDeliveryMapCard(CatalogProduct product) {
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    final apartment = _apartmentController.text.trim();
    final hasDestination = city.isNotEmpty && address.isNotEmpty;
    final isPickup = _deliveryMethod == DeliveryMethod.pickup;
    final fallbackRoute = OrderMapLocationResolver.resolveRoute(
      deliveryMethod: _deliveryMethod,
      city: city,
      address: address,
      apartment: apartment,
    );
    final routeRequest = (
      deliveryMethod: _deliveryMethod,
      city: city,
      address: address,
      apartment: apartment,
    );
    final routeAsync = hasDestination
        ? ref.watch(checkoutPreviewRouteProvider(routeRequest))
        : null;
    final previewRoute = routeAsync?.asData?.value;
    final isResolvingRoute = hasDestination && (routeAsync?.isLoading ?? false);
    final originPoint = _latLngFromGeoPoint(
      previewRoute?.originLocation ?? fallbackRoute.originLocation,
    );
    final destinationPoint = hasDestination && !isResolvingRoute
        ? _latLngFromGeoPoint(
            previewRoute?.destinationLocation ??
                fallbackRoute.destinationLocation,
          )
        : null;

    final statusValue = hasDestination
        ? isPickup
              ? _t(ru: 'Точка выдачи закреплена', en: 'Pickup point pinned')
              : _t(ru: 'Адрес доставки закреплён', en: 'Destination pinned')
        : _t(ru: 'Добавьте адрес', en: 'Add destination');

    final etaValue = product.preorder && _selectedDate != null
        ? formatDate(_selectedDate!)
        : isPickup
        ? _t(ru: '20 МИН', en: '20 MIN')
        : _t(ru: '45 МИН', en: '45 MIN');

    final note = hasDestination
        ? isPickup
              ? _t(
                  ru: 'Карта показывает закреплённую точку самовывоза. При изменении адреса превью обновится сразу.',
                  en: 'The map shows the selected pickup point. Update the address fields and the preview will refresh instantly.',
                )
              : _t(
                  ru: 'Маршрут построен на основе введённого города и адреса. Вы можете изменить поля вручную в любой момент.',
                  en: 'The route is built from the current city and address fields. You can still type your own destination at any time.',
                )
        : _t(
            ru: 'Введите город и адрес доставки, чтобы карта сразу показала точку назначения.',
            en: 'Enter the city and delivery address to pin the destination on the map.',
          );

    final locatingStatus = _t(
      ru: '\u0418\u0449\u0435\u043c \u0442\u043e\u0447\u043a\u0443 \u043d\u0430 \u043a\u0430\u0440\u0442\u0435',
      en: 'Locating address',
    );
    final locatingNote = _t(
      ru: '\u0418\u0449\u0435\u043c \u0442\u043e\u0447\u043d\u044b\u0439 \u0430\u0434\u0440\u0435\u0441 \u043d\u0430 \u043a\u0430\u0440\u0442\u0435. \u041c\u0430\u0440\u043a\u0435\u0440\u044b \u043f\u043e\u044f\u0432\u044f\u0442\u0441\u044f \u043f\u043e\u0441\u043b\u0435 \u043f\u043e\u0438\u0441\u043a\u0430.',
      en: 'The map is resolving the address coordinates. Markers will appear as soon as the lookup finishes.',
    );
    final resolvedStatusValue = !hasDestination
        ? statusValue
        : isResolvingRoute
        ? locatingStatus
        : statusValue;
    final resolvedNote = !hasDestination
        ? note
        : isResolvingRoute
        ? locatingNote
        : note;

    return OrderDeliveryMapCard(
      sectionLabel: _t(ru: 'КАРТА ДОСТАВКИ', en: 'DELIVERY MAP'),
      badgeLabel: !hasDestination
          ? _t(
              ru: '\u041e\u0416\u0418\u0414\u0410\u0415\u0422 \u0410\u0414\u0420\u0415\u0421',
              en: 'WAITING FOR ADDRESS',
            )
          : isResolvingRoute
          ? _t(
              ru: '\u041f\u041e\u0418\u0421\u041a \u0410\u0414\u0420\u0415\u0421\u0410',
              en: 'LOCATING ADDRESS',
            )
          : _t(
              ru: '\u041f\u0420\u0415\u0412\u042c\u042e \u0410\u041a\u0422\u0418\u0412\u041d\u041e',
              en: 'PREVIEW ACTIVE',
            ),

      statusLabel: _t(ru: 'СТАТУС', en: 'STATUS'),
      statusValue: resolvedStatusValue,
      etaLabel: product.preorder && _selectedDate != null
          ? _t(ru: 'ДАТА ГОТОВНОСТИ', en: 'READY DATE')
          : _t(ru: 'ОЖИДАЕМОЕ ВРЕМЯ', en: 'EXPECTED TIME'),
      etaValue: etaValue,
      locationLabel: _t(ru: 'ЛОКАЦИЯ', en: 'LOCATION'),
      locationValue: _composeDeliveryLocation(city, address, apartment),
      amountLabel: _t(ru: 'ИТОГО', en: 'TOTAL'),
      amountValue: formatCurrency(_totalPrice(product)),
      helperText: resolvedNote,
      footerLabel: isPickup
          ? _t(ru: 'MAP / PICKUP SNAPSHOT', en: 'MAP / PICKUP SNAPSHOT')
          : _t(ru: 'MAP / ADDRESS SNAPSHOT', en: 'MAP / ADDRESS SNAPSHOT'),
      modeLabel: isPickup
          ? _t(ru: 'PICKUP MODE', en: 'PICKUP MODE')
          : _t(ru: 'ROUTE PREVIEW', en: 'ROUTE PREVIEW'),
      cityLabel: (city.isEmpty ? _t(ru: 'ГОРОД', en: 'CITY') : city)
          .toUpperCase(),
      originLabel: _t(ru: 'ATELIER', en: 'ATELIER'),
      destinationLabel: isPickup
          ? _t(ru: 'PICKUP', en: 'PICKUP')
          : _t(ru: 'DROP', en: 'DROP'),
      progress: destinationPoint == null ? 0 : (isPickup ? 0.56 : 0.22),
      isLive: false,
      isPickup: isPickup,
      isCompleted: false,
      origin: originPoint,
      destination: destinationPoint,
      courier: destinationPoint == null || isPickup ? null : originPoint,
    );
  }

  Widget _buildTrackingDeliveryMapCard(OrderModel order) {
    final isPickup = order.deliveryMethod == DeliveryMethod.pickup;
    final routeLocations =
        order.originLocation != null && order.destinationLocation != null
        ? OrderRouteLocations(
            originLocation: order.originLocation!,
            destinationLocation: order.destinationLocation!,
          )
        : OrderMapLocationResolver.resolveRoute(
            deliveryMethod: order.deliveryMethod,
            city: order.deliveryCity,
            address: order.deliveryAddress,
            apartment: order.apartment,
          );
    final liveCourierLocation = !isPickup
        ? order.courierLocation ?? routeLocations.originLocation
        : null;

    return OrderDeliveryMapCard(
      sectionLabel: isPickup
          ? _t(ru: 'КАРТА ВЫДАЧИ', en: 'PICKUP MAP')
          : _t(ru: 'КАРТА ДОСТАВКИ', en: 'DELIVERY MAP'),
      badgeLabel: _trackingMapBadge(order),
      statusLabel: _t(ru: 'СТАТУС', en: 'STATUS'),
      statusValue: _trackingMapStatus(order),
      etaLabel: _trackingEtaLabel(order),
      etaValue: _trackingEtaValue(order),
      locationLabel: isPickup
          ? _t(ru: 'ТОЧКА ВЫДАЧИ', en: 'PICKUP POINT')
          : _t(ru: 'ЛОКАЦИЯ', en: 'LOCATION'),
      locationValue: _composeDeliveryLocation(
        order.deliveryCity,
        order.deliveryAddress,
        order.apartment,
      ),
      amountLabel: _t(ru: 'СУММА', en: 'TOTAL'),
      amountValue: formatCurrency(order.totalAmount),
      helperText: _trackingMapNote(order),
      footerLabel: _trackingMapFooter(order),
      modeLabel: _trackingModeTag(order),
      cityLabel:
          (order.deliveryCity.isEmpty
                  ? _t(ru: 'ГОРОД', en: 'CITY')
                  : order.deliveryCity)
              .toUpperCase(),
      originLabel: isPickup
          ? _t(ru: 'AVISHU', en: 'AVISHU')
          : _t(ru: 'ATELIER', en: 'ATELIER'),
      destinationLabel: isPickup
          ? _t(ru: 'PICKUP', en: 'PICKUP')
          : _t(ru: 'CLIENT', en: 'CLIENT'),
      progress: _trackingRouteProgress(order),
      isLive: !isPickup && order.status == OrderStatus.ready,
      isPickup: isPickup,
      isCompleted: order.status == OrderStatus.completed,
      origin: _latLngFromGeoPoint(routeLocations.originLocation),
      destination: _latLngFromGeoPoint(routeLocations.destinationLocation),
      courier: liveCourierLocation == null
          ? null
          : _latLngFromGeoPoint(liveCourierLocation),
      updatedAt: order.courierLocationUpdatedAt,
    );
  }

  String _composeDeliveryLocation(
    String city,
    String address,
    String apartment,
  ) {
    if (city.isEmpty && address.isEmpty) {
      return _t(
        ru: 'Точка назначения появится после ввода адреса.',
        en: 'The destination will appear once the address is entered.',
      );
    }
    if (apartment.isEmpty) {
      return [city, address].where((value) => value.isNotEmpty).join(', ');
    }
    return [
      city,
      address,
      apartment,
    ].where((value) => value.isNotEmpty).join(', ');
  }

  double _trackingRouteProgress(OrderModel order) {
    if (order.deliveryMethod == DeliveryMethod.courier &&
        order.originLocation != null &&
        order.destinationLocation != null &&
        order.courierLocation != null) {
      final fullDistance = _distanceBetweenGeoPoints(
        order.originLocation!,
        order.destinationLocation!,
      );
      if (fullDistance > 0) {
        final completedDistance = _distanceBetweenGeoPoints(
          order.originLocation!,
          order.courierLocation!,
        );
        return (completedDistance / fullDistance).clamp(0.0, 1.0);
      }
    }

    switch (order.status) {
      case OrderStatus.newOrder:
        return 0.14;
      case OrderStatus.accepted:
        return order.deliveryMethod == DeliveryMethod.pickup ? 0.34 : 0.28;
      case OrderStatus.inProduction:
        return order.deliveryMethod == DeliveryMethod.pickup ? 0.58 : 0.52;
      case OrderStatus.ready:
        return order.deliveryMethod == DeliveryMethod.pickup ? 0.88 : 0.82;
      case OrderStatus.completed:
        return 1;
      case OrderStatus.cancelled:
        return 0.08;
    }
  }

  DateTime? _trackingEta(OrderModel order) {
    if (order.status == OrderStatus.cancelled) {
      return null;
    }

    if (order.status == OrderStatus.completed) {
      return order.completedAt ?? order.lastStatusChangedAt;
    }

    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return order.readyBy ??
          order.estimatedReadyAt ??
          order.lastStatusChangedAt.add(const Duration(minutes: 45));
    }

    if (order.status == OrderStatus.ready &&
        order.courierLocation != null &&
        order.destinationLocation != null) {
      final remainingKm = _distanceBetweenGeoPoints(
        order.courierLocation!,
        order.destinationLocation!,
      );
      final etaMinutes = (remainingKm / 0.45).round().clamp(6, 120);
      final baseline =
          order.courierLocationUpdatedAt ?? order.lastStatusChangedAt;
      return baseline.add(Duration(minutes: etaMinutes));
    }

    switch (order.status) {
      case OrderStatus.newOrder:
        return order.createdAt.add(const Duration(minutes: 95));
      case OrderStatus.accepted:
        return order.lastStatusChangedAt.add(const Duration(minutes: 70));
      case OrderStatus.inProduction:
        return order.lastStatusChangedAt.add(const Duration(minutes: 45));
      case OrderStatus.ready:
        return order.lastStatusChangedAt.add(const Duration(minutes: 22));
      case OrderStatus.completed:
        return order.completedAt ?? order.lastStatusChangedAt;
      case OrderStatus.cancelled:
        return null;
    }
  }

  String _trackingEtaLabel(OrderModel order) {
    if (order.status == OrderStatus.completed) {
      return _t(ru: 'ЗАВЕРШЕНО В', en: 'COMPLETED AT');
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(ru: 'ОБНОВЛЕНИЕ', en: 'UPDATE');
    }
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(ru: 'ОКНО ВЫДАЧИ', en: 'PICKUP WINDOW');
    }
    return _t(ru: 'ОЖИДАЕМОЕ ВРЕМЯ', en: 'EXPECTED TIME');
  }

  String _trackingEtaValue(OrderModel order) {
    if (order.status == OrderStatus.cancelled) {
      return _t(ru: 'ОТМЕНЁН', en: 'CANCELLED');
    }

    final eta = _trackingEta(order);
    if (eta == null) {
      return _t(ru: 'УТОЧНЯЕТСЯ', en: 'UPDATING');
    }
    return _formatEtaStamp(eta);
  }

  String _trackingMapStatus(OrderModel order) {
    switch (order.status) {
      case OrderStatus.newOrder:
        return _t(ru: 'Маршрут формируется', en: 'Route is forming');
      case OrderStatus.accepted:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(ru: 'Подготовка к выдаче', en: 'Preparing pickup')
            : _t(ru: 'Назначаем курьера', en: 'Assigning courier');
      case OrderStatus.inProduction:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(ru: 'Сборка заказа', en: 'Preparing the order')
            : _t(ru: 'Упаковка перед выездом', en: 'Packing before dispatch');
      case OrderStatus.ready:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(ru: 'Готов к самовывозу', en: 'Ready for pickup')
            : _t(ru: 'Курьер в пути', en: 'Courier en route');
      case OrderStatus.completed:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(ru: 'Выдано клиенту', en: 'Picked up')
            : _t(ru: 'Доставлено', en: 'Delivered');
      case OrderStatus.cancelled:
        return _t(ru: 'Заказ отменён', en: 'Order cancelled');
    }
  }

  String _trackingMapBadge(OrderModel order) {
    if (order.status == OrderStatus.completed) {
      return _t(ru: 'ЗАВЕРШЁН', en: 'COMPLETE');
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(ru: 'АРХИВ', en: 'ARCHIVED');
    }
    if (order.deliveryMethod == DeliveryMethod.pickup &&
        order.status == OrderStatus.ready) {
      return _t(ru: 'ВЫДАЧА ОТКРЫТА', en: 'PICKUP OPEN');
    }
    if (order.deliveryMethod == DeliveryMethod.courier &&
        order.status == OrderStatus.ready) {
      return _t(ru: 'LIVE UPDATE', en: 'LIVE UPDATE');
    }
    return _t(ru: 'СИНХРОНИЗАЦИЯ', en: 'SYNCED');
  }

  String _trackingModeTag(OrderModel order) {
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(ru: 'PICKUP DESK', en: 'PICKUP DESK');
    }
    if (order.status == OrderStatus.ready) {
      return _t(ru: 'LIVE COURIER', en: 'LIVE COURIER');
    }
    return _t(ru: 'ROUTE CONTROL', en: 'ROUTE CONTROL');
  }

  String _trackingMapFooter(OrderModel order) {
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(ru: 'MAP / PICKUP STATUS', en: 'MAP / PICKUP STATUS');
    }
    if (order.courierLocationUpdatedAt != null) {
      return 'LIVE / ${_clockLabel(order.courierLocationUpdatedAt!)}';
    }
    return _t(ru: 'MAP / COURIER STATUS', en: 'MAP / COURIER STATUS');
  }

  String _trackingMapNote(OrderModel order) {
    if (order.status == OrderStatus.completed) {
      return _t(
        ru: 'Доставка завершена. На карте сохранён финальный маршрут и итоговая сумма заказа в тенге.',
        en: 'The delivery is complete. The map keeps the final route and the total order amount in tenge.',
      );
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(
        ru: 'Заказ отменён, поэтому live-маршрут больше не обновляется.',
        en: 'The order was cancelled, so the live route is no longer updating.',
      );
    }
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(
        ru: 'Точка выдачи закреплена в заказе. Как только изделие будет готово, окно самовывоза останется здесь.',
        en: 'The pickup point is fixed in the order. Once the garment is ready, the pickup window will stay visible here.',
      );
    }
    if (order.status == OrderStatus.ready) {
      return _t(
        ru: 'Курьер уже на маршруте. ETA обновляется от последней передачи заказа в доставку.',
        en: 'The courier is already on the route. ETA updates from the latest handoff to delivery.',
      );
    }
    return _t(
      ru: 'Маршрут подготовлен заранее: как только заказ перейдёт в доставку, карта автоматически станет live.',
      en: 'The route is prepared in advance. As soon as the order enters delivery, the map will switch to live mode.',
    );
  }

  String _formatEtaStamp(DateTime value) {
    final now = DateTime.now();
    final isSameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    if (isSameDay) {
      return _clockLabel(value);
    }
    return '${formatDate(value)} / ${_clockLabel(value)}';
  }

  String _clockLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  LatLng _latLngFromGeoPoint(GeoPoint point) {
    return LatLng(point.latitude, point.longitude);
  }

  double _distanceBetweenGeoPoints(GeoPoint start, GeoPoint end) {
    const distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _latLngFromGeoPoint(start),
      _latLngFromGeoPoint(end),
    );
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
                  '${_t(ru: 'СОРТИРОВАТЬ', en: 'SORT', kk: 'СҰРЫПТАУ')}: ${_sortOption.labelFor(_language).toUpperCase()}',
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
          _t(ru: 'РАЗМЕР КАРТОЧЕК', en: 'CARD SIZE', kk: 'КАРТОЧКА ӨЛШЕМІ'),
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
                          : 'LARGE', kk: size == CatalogCardSize.compact
                          ? 'КІШІРЕК'
                          : size == CatalogCardSize.standard
                          ? 'ТЕҢГЕРІЛГЕН'
                          : 'ІРІРЕК')}',
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
                label: _t(ru: 'Все', en: 'All', kk: 'Барлығы'),
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
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.black
              : enabled
              ? AppColors.surfaceLowest
              : AppColors.surfaceHigh,
          border: Border.all(
            color: enabled ? AppColors.black : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: selected
                ? AppColors.white
                : enabled
                ? AppColors.black
                : AppColors.secondary,
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
                    _scrollToThumbnail(index);
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
            controller: _thumbnailScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 24),
            itemCount: product.imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = index == _selectedImageIndex;
              return InkWell(
                onTap: () {
                  setState(() => _selectedImageIndex = index);
                  _scrollToThumbnail(index);
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
      height: double.infinity,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _quantity.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: () => setState(() => _quantity++),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
            ),
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
          ClientCatalogMediaCarousel(
            imageUrls: product.imageUrls,
            aspectRatio: _catalogCardAspectRatio,
            leadingChip: _metaChip(categoryLabel),
            trailingChip: product.isNew
                ? _metaChip(_t(ru: 'Новинка', en: 'New', kk: 'Жаңа'))
                : null,
            isFavorite: isFavorite,
            onFavoriteTap: () {
              setState(() => _toggleFavorite(product.id));
            },
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
              _metaChip(_catalogSizeChipLabel(product)),
              _metaChip(
                _t(
                  ru: '${product.colors.length} цвета',
                  en: '${product.colors.length} colors',
                  kk: '${product.colors.length} түс',
                ),
              ),
              if (product.unavailableSizeCount > 0)
                _metaChip(
                  _t(
                    ru: '-${product.unavailableSizeCount} разм.',
                    en: '-${product.unavailableSizeCount} sizes',
                    kk: '-${product.unavailableSizeCount} өлшем',
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
                  '${_t(ru: 'ЗАКАЗ', en: 'ORDER', kk: 'ТАПСЫРЫС')} #${order.shortId}',
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
    final imageUri = Uri.tryParse(url);
    final isDirectWebp = (imageUri?.path.toLowerCase() ?? '').endsWith('.webp');
    if (isDirectWebp) {
      return FutureBuilder<Uint8List>(
        future: _loadImageBytes(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _productImagePlaceholder(
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _productImagePlaceholder(
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.grey,
                ),
              ),
            );
          }

          return Image.memory(
            snapshot.data!,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return _productImagePlaceholder(
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.grey,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return _productImagePlaceholder(
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _productImagePlaceholder(
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

  Future<Uint8List> _loadImageBytes(String url) async {
    final bundle = NetworkAssetBundle(Uri.parse(url));
    final data = await bundle.load(url);
    return data.buffer.asUint8List();
  }

  void _scrollToThumbnail(int index) {
    if (!_thumbnailScrollController.hasClients) {
      return;
    }

    const itemWidth = 74.0;
    const itemSpacing = 8.0;
    final targetOffset = (index * (itemWidth + itemSpacing)) - 16;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    );
    _thumbnailScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _productImagePlaceholder({required Widget child}) {
    return Container(color: AppColors.surfaceHigh, child: child);
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
                          _t(
                            ru: 'РАЗДЕЛЫ КАТАЛОГА',
                            en: 'CATALOG SECTIONS',
                            kk: 'КАТАЛОГ БӨЛІМДЕРІ',
                          ),
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
    final screenSize = MediaQuery.sizeOf(context);
    final wideViewport = screenSize.width >= 720;
    final maxSheetWidth = wideViewport ? 960.0 : screenSize.width;
    final sheetHeight = screenSize.height * (wideViewport ? 0.82 : 0.9);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wideViewport ? 16 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxSheetWidth),
                child: SizedBox(
                  height: sheetHeight,
                  child: Material(
                    color: AppColors.surfaceLowest,
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
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
                ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 720;

            return Column(
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
                if (compactLayout)
                  _sizeGuideCompactGrid(group)
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      border: const TableBorder(
                        horizontalInside: BorderSide(
                          color: AppColors.outlineVariant,
                        ),
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
            );
          },
        ),
      ),
    );
  }

  Widget _sizeGuideCompactGrid(SizeGuideGroup group) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final singleColumn = constraints.maxWidth < 360;
        final cardWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: group.columns
              .map(
                (column) => SizedBox(
                  width: cardWidth,
                  child: _sizeGuideSizeCard(column),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _sizeGuideSizeCard(SizeGuideColumn column) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              column.size,
              textAlign: TextAlign.center,
              style: AppTypography.button.copyWith(
                color: AppColors.white,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _sizeGuideMetricRow(
                  _t(ru: 'Обхват груди', en: 'Bust'),
                  column.chest,
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 10),
                _sizeGuideMetricRow(
                  _t(ru: 'Обхват талии', en: 'Waist'),
                  column.waist,
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 10),
                _sizeGuideMetricRow(
                  _t(ru: 'Обхват бедер', en: 'Hips'),
                  column.hips,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeGuideMetricRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
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

class _DeliveryAddressPreset {
  final String labelRu;
  final String labelEn;
  final String labelKk;
  final String city;
  final String address;
  final String apartment;

  const _DeliveryAddressPreset({
    required this.labelRu,
    required this.labelEn,
    required this.labelKk,
    required this.city,
    required this.address,
    required this.apartment,
  });
}

class _CatalogPriceRangeSlider extends StatefulWidget {
  const _CatalogPriceRangeSlider({
    required this.min,
    required this.max,
    required this.divisions,
    required this.values,
    required this.onChangedEnd,
    required this.valueFormatter,
  });

  final double min;
  final double max;
  final int divisions;
  final RangeValues values;
  final ValueChanged<RangeValues> onChangedEnd;
  final String Function(double value) valueFormatter;

  @override
  State<_CatalogPriceRangeSlider> createState() =>
      _CatalogPriceRangeSliderState();
}

class _CatalogPriceRangeSliderState extends State<_CatalogPriceRangeSlider> {
  late RangeValues _localValues;

  @override
  void initState() {
    super.initState();
    _localValues = widget.values;
  }

  @override
  void didUpdateWidget(covariant _CatalogPriceRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.divisions != widget.divisions) {
      _localValues = widget.values;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            values: _localValues,
            onChanged: (values) {
              setState(() => _localValues = values);
            },
            onChangeEnd: widget.onChangedEnd,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.valueFormatter(_localValues.start)),
            Text(widget.valueFormatter(_localValues.end)),
          ],
        ),
      ],
    );
  }
}
