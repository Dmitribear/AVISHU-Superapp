import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
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
        return tr(
          language,
          ru: 'Р СџР С• РЎС“Р СР С•Р В»РЎвЂЎР В°Р Р…Р С‘РЎР‹',
          en: 'Default',
        );
      case CatalogSortOption.newFirst:
        return tr(
          language,
          ru: 'Р РЋР Р…Р В°РЎвЂЎР В°Р В»Р В° Р Р…Р С•Р Р†Р С‘Р Р…Р С”Р С‘',
          en: 'New First',
        );
      case CatalogSortOption.priceLowToHigh:
        return tr(
          language,
          ru: 'Р В¦Р ВµР Р…Р В°: Р С—Р С• Р Р†Р С•Р В·РЎР‚Р В°РЎРѓРЎвЂљР В°Р Р…Р С‘РЎР‹',
          en: 'Price: Low to High',
        );
      case CatalogSortOption.priceHighToLow:
        return tr(
          language,
          ru: 'Р В¦Р ВµР Р…Р В°: Р С—Р С• РЎС“Р В±РЎвЂ№Р Р†Р В°Р Р…Р С‘РЎР‹',
          en: 'Price: High to Low',
        );
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
  final _cityController = TextEditingController(
    text: 'Р С’Р В»Р СР В°РЎвЂљРЎвЂ№',
  );
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

  String _t({required String ru, required String en, String? kk}) {
    return tr(_language, ru: ru, en: en, kk: kk);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(
        ru: 'Р СџР С’Р СњР вЂўР вЂєР В¬',
        en: 'HOME',
        kk: 'Р СџР С’Р СњР вЂўР вЂєР В¬',
      ),
      icon: Icons.grid_view_rounded,
    ),
    AvishuNavItem(
      label: _t(
        ru: 'Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ',
        en: 'CATALOG',
        kk: 'Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ',
      ),
      icon: Icons.layers_outlined,
    ),
    AvishuNavItem(
      label: _t(
        ru: 'Р ВР РЋР СћР С›Р В Р ВР Р‡',
        en: 'ORDERS',
        kk: 'Р СћР С’Р В Р ВР ТђР В«',
      ),
      icon: Icons.inventory_2_outlined,
    ),
    AvishuNavItem(
      label: _t(
        ru: 'Р СџР В Р С›Р В¤Р ВР вЂєР В¬',
        en: 'PROFILE',
        kk: 'Р СџР В Р С›Р В¤Р ВР вЂєР В¬',
      ),
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
            _t(
              ru: 'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘: $err',
              en: 'Loading error: $err',
            ),
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
            ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћР С›Р вЂ™Р С’Р В ',
            en: 'CLIENT / PRODUCT',
            kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћР С’Р Р€Р С’Р В ',
          );
        }
        return '${_t(ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ', en: 'CLIENT', kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ')} / '
            '${localizeCatalogSection(_language, _selectedProduct!.category).toUpperCase()}';
      case ClientView.checkout:
        return _t(
          ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р С›Р В¤Р С›Р В Р СљР вЂєР вЂўР СњР ВР вЂў',
          en: 'CLIENT / CHECKOUT',
          kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋ',
        );
      case ClientView.payment:
        return _t(
          ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р С›Р СџР вЂєР С’Р СћР С’',
          en: 'CLIENT / PAYMENT',
          kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћРЈРЃР вЂєР вЂўР Сљ',
        );
      case ClientView.tracking:
        return _t(
          ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћР В Р вЂўР С™Р ВР СњР вЂњ',
          en: 'CLIENT / TRACKING',
          kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р вЂР С’РўС™Р В«Р вЂєР С’Р Р€',
        );
      case ClientView.root:
        switch (_tab) {
          case ClientTab.dashboard:
            return _t(
              ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СџР С’Р СњР вЂўР вЂєР В¬',
              en: 'CLIENT / HOME',
              kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СџР С’Р СњР вЂўР вЂєР В¬',
            );
          case ClientTab.collections:
            return _t(
              ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ',
              en: 'CLIENT / CATALOG',
              kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ',
            );
          case ClientTab.archive:
            return _t(
              ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р ВР РЋР СћР С›Р В Р ВР Р‡',
              en: 'CLIENT / ORDERS',
              kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СћР С’Р В Р ВР ТђР В«',
            );
          case ClientTab.profile:
            return _t(
              ru: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СџР В Р С›Р В¤Р ВР вЂєР В¬',
              en: 'CLIENT / PROFILE',
              kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ / Р СџР В Р С›Р В¤Р ВР вЂєР В¬',
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
            ru: 'Р С™Р С’Р СџР РЋР Р€Р вЂєР С’ Р РЋР вЂўР вЂ”Р С›Р СњР С’',
            en: 'SEASON CAPSULE',
            kk: 'Р СљР С’Р Р€Р РЋР В«Р СљР вЂќР В«РўС™ Р С™Р С’Р СџР РЋР Р€Р вЂєР С’',
          ),
          subtitle: _t(
            ru: 'Р С™Р В°РЎвЂљР В°Р В»Р С•Р С– РЎРѓР С•Р В±РЎР‚Р В°Р Р… РЎРѓ РЎР‚Р В°Р В·Р Т‘Р ВµР В»Р В°Р СР С‘, РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р В°Р СР С‘, РЎРѓР С•РЎР‚РЎвЂљР С‘РЎР‚Р С•Р Р†Р С”Р С•Р в„– Р С‘ Р С—Р С•Р В»Р Р…Р С•РЎвЂ Р ВµР Р…Р Р…Р С•Р в„– Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р С•Р в„– РЎвЂљР С•Р Р†Р В°РЎР‚Р В° Р Р† РЎвЂћР С‘РЎР‚Р СР ВµР Р…Р Р…Р С•Р С AVISHU-РЎР‚Р С‘РЎвЂљР СР Вµ.',
            en: 'The catalog now combines sections, filters, sorting, and a full product card in the AVISHU rhythm.',
            kk: 'Р С™Р В°РЎвЂљР В°Р В»Р С•Р С– Р В±РЈВ©Р В»РЎвЂ“Р СР Т‘Р ВµРЎР‚Р СР ВµР Р…, РЎРѓРўР‡Р В·Р С–РЎвЂ“Р В»Р ВµРЎР‚Р СР ВµР Р…, РЎРѓРўВ±РЎР‚РЎвЂ№Р С—РЎвЂљР В°РЎС“Р СР ВµР Р… Р В¶РЈв„ўР Р…Р Вµ РЎвЂћР С‘РЎР‚Р СР В°Р В»РЎвЂ№РўвЂє AVISHU-РЎвЂ№РЎР‚РўвЂњР В°РўвЂњРЎвЂ№Р Р…Р Т‘Р В°РўвЂњРЎвЂ№ РЎвЂљР С•Р В»РЎвЂ№РўвЂєРўвЂєР В°Р Р…Р Т‘РЎвЂ№ РЎвЂљР В°РЎС“Р В°РЎР‚ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р В°РЎРѓРЎвЂ№Р СР ВµР Р… Р В¶Р С‘Р Р…Р В°РўвЂєРЎвЂљР В°Р В»РўвЂњР В°Р Р….',
          ),
          accent: _t(
            ru: 'Р СњР С›Р вЂ™Р В«Р Тђ Р СљР С›Р вЂќР вЂўР вЂєР вЂўР в„ў: ${_catalogProducts.where((item) => item.isNew).length}',
            en: 'NEW MODELS: ${_catalogProducts.where((item) => item.isNew).length}',
            kk: 'Р вЂ“Р С’РўСћР С’ Р СљР С›Р вЂќР вЂўР вЂєР В¬Р вЂќР вЂўР В : ${_catalogProducts.where((item) => item.isNew).length}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: _t(
                  ru: 'Р СџРЎР‚Р ВµР Т‘Р В·Р В°Р С”Р В°Р В·РЎвЂ№',
                  en: 'Preorders',
                  kk: 'Р С’Р В»Р Т‘РЎвЂ№Р Р… Р В°Р В»Р В° РЎвЂљР В°Р С—РЎРѓРЎвЂ№РЎР‚РЎвЂ№РЎРѓРЎвЂљР В°РЎР‚',
                ),
                value: preorderCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                label: _t(
                  ru: 'Р вЂєРЎР‹Р В±Р С‘Р СРЎвЂ№Р Вµ',
                  en: 'Favorites',
                  kk: 'Р СћР В°РўР€Р Т‘Р В°РЎС“Р В»РЎвЂ№Р В»Р В°РЎР‚',
                ),
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
                    ru: 'Р С’Р С™Р СћР ВР вЂ™Р СњР В«Р в„ў Р вЂ”Р С’Р С™Р С’Р вЂ”',
                    en: 'ACTIVE ORDER',
                    kk: 'Р вЂР вЂўР вЂєР РЋР вЂўР СњР вЂќР вЂ  Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋ',
                  ),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    ru: 'Р вЂ”Р В°Р С”Р В°Р В·Р С•Р Р† Р С—Р С•Р С”Р В° Р Р…Р ВµРЎвЂљ',
                    en: 'No orders yet',
                    kk: 'РЈВР В·РЎвЂ“РЎР‚Р С–Р Вµ РЎвЂљР В°Р С—РЎРѓРЎвЂ№РЎР‚РЎвЂ№РЎРѓРЎвЂљР В°РЎР‚ Р В¶Р С•РўвЂє',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    ru: 'Р С›РЎвЂљР С”РЎР‚Р С•Р в„–РЎвЂљР Вµ Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–, Р Р…Р В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–РЎвЂљР Вµ Р Р†РЎвЂ№Р Т‘Р В°РЎвЂЎРЎС“ Р С”Р В°Р С” Р Р…Р В° РЎРѓР В°Р в„–РЎвЂљР Вµ Р С‘ Р С•РЎвЂћР С•РЎР‚Р СР С‘РЎвЂљР Вµ Р С—Р ВµРЎР‚Р Р†РЎвЂ№Р в„– Р В·Р В°Р С”Р В°Р В· Р Р† Р С•Р Т‘Р Р…Р С•Р С Р С—Р С•РЎвЂљР С•Р С”Р Вµ.',
                    en: 'Open the catalog, adjust the feed like on the website, and place the first order in one flow.',
                    kk: 'Р С™Р В°РЎвЂљР В°Р В»Р С•Р С–РЎвЂљРЎвЂ№ Р В°РЎв‚¬РЎвЂ№РўР€РЎвЂ№Р В·, РЎРѓР В°Р в„–РЎвЂљРЎвЂљР В°РўвЂњРЎвЂ№ РЎРѓР С‘РЎРЏРўвЂєРЎвЂљРЎвЂ№ Р С”РЈВ©РЎР‚РЎРѓР ВµРЎвЂљРЎвЂ“Р В»РЎвЂ“Р СР Т‘РЎвЂ“ РЎР‚Р ВµРЎвЂљРЎвЂљР ВµРўР€РЎвЂ“Р В· Р В¶РЈв„ўР Р…Р Вµ Р В±РЎвЂ“РЎР‚ Р В»Р ВµР С”Р С—Р ВµР Р… Р В°Р В»РўвЂњР В°РЎв‚¬РўвЂєРЎвЂ№ РЎвЂљР В°Р С—РЎРѓРЎвЂ№РЎР‚РЎвЂ№РЎРѓРЎвЂљРЎвЂ№ РЎР‚Р ВµРЎРѓРЎвЂ“Р СР Т‘Р ВµРўР€РЎвЂ“Р В·.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          _orderCard(
            order: activeOrder,
            cta: _t(
              ru: 'Р С›Р СћР РЋР вЂєР вЂўР вЂќР ВР СћР В¬',
              en: 'TRACK',
              kk: 'Р вЂР С’РўС™Р В«Р вЂєР С’Р Р€',
            ),
            onTap: () {
              setState(() {
                _latestOrderId = activeOrder.id;
                _view = ClientView.tracking;
              });
            },
          ),
        const SizedBox(height: 12),
        _sectionLabel(
          _t(
            ru: 'Р вЂР В«Р РЋР СћР В Р В«Р в„ў Р вЂ™Р В«Р вЂР С›Р В ',
            en: 'QUICK PICK',
            kk: 'Р вЂ“Р вЂўР вЂќР вЂўР вЂє Р СћР С’РўСћР вЂќР С’Р Р€',
          ),
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
                    ru: 'Р СџР ВµРЎР‚Р ВµР в„–РЎвЂљР С‘ Р Р† Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–',
                    en: 'Open Catalog',
                    kk: 'Р С™Р В°РЎвЂљР В°Р В»Р С•Р С–РўвЂєР В° РЈВ©РЎвЂљРЎС“',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AvishuButton(
                text: _t(
                  ru: 'Р С›Р СћР С™Р В Р В«Р СћР В¬',
                  en: 'OPEN',
                  kk: 'Р С’Р РЃР Р€',
                ),
                onPressed: () {
                  setState(() {
                    _tab = ClientTab.collections;
                    _view = ClientView.root;
                    _selectSection('Р СњР С•Р Р†Р С‘Р Р…Р С”Р С‘');
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
        ? _t(
            ru: 'Р ВР вЂ”Р вЂР В Р С’Р СњР СњР С›Р вЂў',
            en: 'FAVORITES',
            kk: 'Р СћР С’РўСћР вЂќР С’Р Р€Р вЂєР В«Р вЂєР С’Р В ',
          )
        : localizeCatalogSection(_language, _activeSection).toUpperCase();
    final filtersSummary = _activeCatalogFiltersCount == 0
        ? _t(
            ru: '${products.length} Р СР С•Р Т‘Р ВµР В»Р ВµР в„–',
            en: '${products.length} items',
            kk: '${products.length} Р СР С•Р Т‘Р ВµР В»РЎРЉ',
          )
        : _t(
            ru: '$_activeCatalogFiltersCount РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р С•Р Р† РІР‚Сћ ${products.length} Р СР С•Р Т‘Р ВµР В»Р ВµР в„–',
            en: '$_activeCatalogFiltersCount filters РІР‚Сћ ${products.length} items',
            kk: '$_activeCatalogFiltersCount РЎРѓРўР‡Р В·Р С–РЎвЂ“ РІР‚Сћ ${products.length} Р СР С•Р Т‘Р ВµР В»РЎРЉ',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t(ru: 'Р вЂњР вЂєР С’Р вЂ™Р СњР С’Р Р‡', en: 'HOME')} / $sectionLabel',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _catalogAccordion(
          eyebrow: _t(
            ru: 'Р В Р С’Р вЂ”Р вЂќР вЂўР вЂєР В« Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњР С’',
            en: 'CATALOG SECTIONS',
            kk: 'Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ Р вЂРЈРЃР вЂєР вЂ Р СљР вЂќР вЂўР В Р вЂ ',
          ),
          title: sectionLabel,
          summary: _showFavoritesOnly
              ? _t(
                  ru: 'Р вЂ™РЎвЂ№Р В±РЎР‚Р В°Р Р…РЎвЂ№ РЎРѓР С•РЎвЂ¦РЎР‚Р В°Р Р…Р ВµР Р…Р Р…РЎвЂ№Р Вµ Р СР С•Р Т‘Р ВµР В»Р С‘ Р С—РЎР‚Р С•РЎвЂћР С‘Р В»РЎРЏ',
                  en: 'Saved profile favorites only',
                  kk: 'Р СџРЎР‚Р С•РЎвЂћР С‘Р В»РЎРЉР Т‘Р ВµР С–РЎвЂ“ РЎРѓР В°РўвЂєРЎвЂљР В°Р В»РўвЂњР В°Р Р… Р СР С•Р Т‘Р ВµР В»РЎРЉР Т‘Р ВµРЎР‚ РЎвЂљР В°РўР€Р Т‘Р В°Р В»Р Т‘РЎвЂ№',
                )
              : _t(
                  ru: 'Р СћР ВµР С”РЎС“РЎвЂ°Р С‘Р в„– РЎР‚Р В°Р В·Р Т‘Р ВµР В» Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–Р В°',
                  en: 'Current catalog section',
                  kk: 'Р С™Р В°РЎвЂљР В°Р В»Р С•Р С–РЎвЂљРЎвЂ№РўР€ Р В°РўвЂњРЎвЂ№Р СР Т‘Р В°РўвЂњРЎвЂ№ Р В±РЈВ©Р В»РЎвЂ“Р СРЎвЂ“',
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
                label: _t(
                  ru: 'Р ВР вЂ”Р вЂР В Р С’Р СњР СњР С›Р вЂў',
                  en: 'FAVORITES',
                  kk: 'Р СћР С’РўСћР вЂќР С’Р Р€Р вЂєР В«Р вЂєР С’Р В ',
                ),
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
            ru: 'Р В¤Р ВР вЂєР В¬Р СћР В Р В« Р В Р РЋР С›Р В Р СћР ВР В Р С›Р вЂ™Р С™Р С’',
            en: 'FILTERS & SORTING',
            kk: 'Р РЋРўВ®Р вЂ”Р вЂњР вЂ Р вЂєР вЂўР В  Р вЂ“РЈВР СњР вЂў Р РЋРўВ°Р В Р В«Р СџР СћР С’Р Р€',
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
                    ru: 'Р С›РЎвЂЎР С‘РЎРѓРЎвЂљР С‘РЎвЂљРЎРЉ Р Р†РЎвЂ№Р В±Р С•РЎР‚',
                    en: 'Clear filters',
                    kk: 'Р СћР В°РўР€Р Т‘Р В°РЎС“Р Т‘РЎвЂ№ РЎвЂљР В°Р В·Р В°РЎР‚РЎвЂљРЎС“',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _filterGroup(
                title: _t(
                  ru: 'Р С™Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘РЎРЏ',
                  en: 'Category',
                  kk: 'Р РЋР В°Р Р…Р В°РЎвЂљ',
                ),
                options: _categoryOptions,
                selectedValue: _categoryFilter,
                optionLabelBuilder: (value) =>
                    localizeCatalogSection(_language, value),
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              _filterGroup(
                title: _t(
                  ru: 'Р В Р В°Р В·Р СР ВµРЎР‚',
                  en: 'Size',
                  kk: 'РЈРЃР В»РЎв‚¬Р ВµР С',
                ),
                options: _sizeOptions,
                selectedValue: _sizeFilter,
                onChanged: (value) => setState(() => _sizeFilter = value),
              ),
              _filterGroup(
                title: _t(
                  ru: 'Р В¦Р Р†Р ВµРЎвЂљ',
                  en: 'Color',
                  kk: 'Р СћРўР‡РЎРѓ',
                ),
                options: _colorOptions,
                selectedValue: _colorFilter,
                onChanged: (value) => setState(() => _colorFilter = value),
              ),
              Text(
                _t(
                  ru: 'Р В¦Р вЂўР СњР С’',
                  en: 'PRICE',
                  kk: 'Р вЂР С’РўвЂ™Р С’',
                ),
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
                  _t(
                    ru: 'Р СњР вЂўР Сћ Р РЋР С›Р вЂ™Р СџР С’Р вЂќР вЂўР СњР ВР в„ў',
                    en: 'NO MATCHES',
                    kk: 'Р РЋРЈВР в„ўР С™Р вЂўР РЋР СћР вЂ Р С™ Р вЂ“Р С›РўС™',
                  ),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 10),
                Text(
                  _showFavoritesOnly
                      ? _t(
                          ru: 'Р вЂ™ Р С‘Р В·Р В±РЎР‚Р В°Р Р…Р Р…Р С•Р С Р С—Р С•Р С”Р В° Р Р…Р ВµРЎвЂљ Р СР С•Р Т‘Р ВµР В»Р ВµР в„–. Р С›РЎвЂљР С”РЎР‚Р С•Р в„–РЎвЂљР Вµ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”РЎС“ РЎвЂљР С•Р Р†Р В°РЎР‚Р В° Р С‘ РЎРѓР С•РЎвЂ¦РЎР‚Р В°Р Р…Р С‘РЎвЂљР Вµ Р ВµР Вµ РЎРѓР ВµРЎР‚Р Т‘РЎвЂ Р ВµР С.',
                          en: 'No favorite models yet. Open a product card and save it with the heart icon.',
                          kk: 'Р СћР В°РўР€Р Т‘Р В°РЎС“Р В»РЎвЂ№Р Т‘Р В° РЈв„ўР В·РЎвЂ“РЎР‚Р С–Р Вµ Р СР С•Р Т‘Р ВµР В»РЎРЉР Т‘Р ВµРЎР‚ Р В¶Р С•РўвЂє. Р СћР В°РЎС“Р В°РЎР‚ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р В°РЎРѓРЎвЂ№Р Р… Р В°РЎв‚¬РЎвЂ№Р С—, Р С•Р Р…РЎвЂ№ Р В¶РўР‡РЎР‚Р ВµР С”РЎв‚¬Р ВµР СР ВµР Р… РЎРѓР В°РўвЂєРЎвЂљР В°РўР€РЎвЂ№Р В·.',
                        )
                      : _t(
                          ru: 'Р СџР С•Р С—РЎР‚Р С•Р В±РЎС“Р в„–РЎвЂљР Вµ РЎРѓР Р…РЎРЏРЎвЂљРЎРЉ Р С•Р Т‘Р С‘Р Р… Р С‘Р В· РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р С•Р Р† Р С‘Р В»Р С‘ Р Р†РЎвЂ№Р В±РЎР‚Р В°РЎвЂљРЎРЉ Р Т‘РЎР‚РЎС“Р С–Р С•Р в„– РЎР‚Р В°Р В·Р Т‘Р ВµР В» Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–Р В°.',
                          en: 'Try clearing a filter or switching to another catalog section.',
                          kk: 'Р РЋРўР‡Р В·Р С–РЎвЂ“Р В»Р ВµРЎР‚Р Т‘РЎвЂ“РўР€ Р В±РЎвЂ“РЎР‚РЎвЂ“Р Р… Р В°Р В»РЎвЂ№Р С— РЎвЂљР В°РЎРѓРЎвЂљР В°Р С— Р С”РЈВ©РЎР‚РЎвЂ“РўР€РЎвЂ“Р В· Р Р…Р ВµР СР ВµРЎРѓР Вµ Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–РЎвЂљРЎвЂ№РўР€ Р В±Р В°РЎРѓРўвЂєР В° Р В±РЈВ©Р В»РЎвЂ“Р СРЎвЂ“Р Р… РЎвЂљР В°РўР€Р Т‘Р В°РўР€РЎвЂ№Р В·.',
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
          'Р вЂњР вЂєР С’Р вЂ™Р СњР С’Р Р‡ / ${_activeSection.toUpperCase()}',
          style: AppTypography.code,
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Р В Р С’Р вЂ”Р вЂќР вЂўР вЂєР В« Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњР С’',
                style: AppTypography.eyebrow,
              ),
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
                          'Р В¤Р С‘Р В»РЎРЉРЎвЂљРЎР‚Р В°РЎвЂ Р С‘РЎРЏ Р С‘ РЎРѓР С•РЎР‚РЎвЂљР С‘РЎР‚Р С•Р Р†Р С”Р В° РЎРѓР С•Р В±РЎР‚Р В°Р Р…РЎвЂ№ Р С—Р С• Р В»Р С•Р С–Р С‘Р С”Р Вµ РЎРѓР В°Р в„–РЎвЂљР В°, Р Р…Р С• Р Р† Р В±Р С•Р В»Р ВµР Вµ Р В¶Р ВµРЎРѓРЎвЂљР С”Р С•Р С Р С‘ РЎвЂЎР С‘РЎРѓРЎвЂљР С•Р С Р СР С•Р В±Р С‘Р В»РЎРЉР Р…Р С•Р С Р С‘Р Р…РЎвЂљР ВµРЎР‚РЎвЂћР ВµР в„–РЎРѓР Вµ AVISHU.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${products.length} Р СР С•Р Т‘Р ВµР В»Р ВµР в„–',
                    style: AppTypography.code,
                  ),
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
                  'Р С›РЎвЂЎР С‘РЎРѓРЎвЂљР С‘РЎвЂљРЎРЉ Р Р†РЎвЂ№Р В±Р С•РЎР‚',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _filterGroup(
                title: 'Р С™Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘РЎРЏ',
                options: _categoryOptions,
                selectedValue: _categoryFilter,
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              _filterGroup(
                title: 'Р В Р В°Р В·Р СР ВµРЎР‚',
                options: _sizeOptions,
                selectedValue: _sizeFilter,
                onChanged: (value) => setState(() => _sizeFilter = value),
              ),
              _filterGroup(
                title: 'Р В¦Р Р†Р ВµРЎвЂљ',
                options: _colorOptions,
                selectedValue: _colorFilter,
                onChanged: (value) => setState(() => _colorFilter = value),
              ),
              Text('Р В¦Р вЂўР СњР С’', style: AppTypography.eyebrow),
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
                  'Р СњР вЂўР Сћ Р РЋР С›Р вЂ™Р СџР С’Р вЂќР вЂўР СњР ВР в„ў',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 10),
                Text(
                  'Р СџР С•Р С—РЎР‚Р С•Р В±РЎС“Р в„–РЎвЂљР Вµ РЎРѓР Р…РЎРЏРЎвЂљРЎРЉ Р С•Р Т‘Р С‘Р Р… Р С‘Р В· РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р С•Р Р† Р С‘Р В»Р С‘ Р Р†РЎвЂ№Р В±РЎР‚Р В°РЎвЂљРЎРЉ Р Т‘РЎР‚РЎС“Р С–Р С•Р в„– РЎР‚Р В°Р В·Р Т‘Р ВµР В» Р С”Р В°РЎвЂљР В°Р В»Р С•Р С–Р В°.',
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
            ru: 'Р ВР РЋР СћР С›Р В Р ВР Р‡ Р вЂ”Р С’Р С™Р С’Р вЂ”Р С›Р вЂ™',
            en: 'ORDER HISTORY',
            kk: 'Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋР СћР С’Р В  Р СљРўВ°Р В Р С’РўвЂ™Р С’Р СћР В«',
          ),
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _surfaceCard(
            child: Text(
              _t(
                ru: 'Р ВРЎРѓРЎвЂљР С•РЎР‚Р С‘РЎРЏ Р С—Р С•РЎРЏР Р†Р С‘РЎвЂљРЎРѓРЎРЏ Р С—Р С•РЎРѓР В»Р Вµ Р С—Р ВµРЎР‚Р Р†Р С•Р С–Р С• Р С•РЎвЂћР С•РЎР‚Р СР В»Р ВµР Р…Р Р…Р С•Р С–Р С• Р В·Р В°Р С”Р В°Р В·Р В°.',
                en: 'History will appear after the first completed checkout.',
                kk: 'Р СћР В°РЎР‚Р С‘РЎвЂ¦ Р В°Р В»РўвЂњР В°РЎв‚¬РўвЂєРЎвЂ№ РЎвЂљР В°Р С—РЎРѓРЎвЂ№РЎР‚РЎвЂ№РЎРѓРЎвЂљР В°Р Р… Р С”Р ВµР в„–РЎвЂ“Р Р… Р С—Р В°Р в„–Р Т‘Р В° Р В±Р С•Р В»Р В°Р Т‘РЎвЂ№.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCard(
              order: order,
              cta: _t(
                ru: 'Р вЂќР вЂўР СћР С’Р вЂєР В',
                en: 'DETAILS',
                kk: 'Р СљРЈВР вЂєР вЂ Р СљР вЂўР СћР СћР вЂўР В ',
              ),
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
    final profile = ref.watch(currentUserProfileProvider).value;
    final favoriteProducts = _favoriteProducts;
    final loyalty = _loyaltySnapshot(profile, orders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  ru: 'Р С™Р вЂєР ВР вЂўР СњР СћР РЋР С™Р ВР в„ў Р СџР В Р С›Р В¤Р ВР вЂєР В¬',
                  en: 'CLIENT PROFILE',
                  kk: 'Р С™Р вЂєР ВР вЂўР СњР Сћ Р СџР В Р С›Р В¤Р ВР вЂєР вЂ ',
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
                        '${_t(ru: 'Р В Р С›Р вЂєР В¬', en: 'ROLE', kk: 'Р В РЈРЃР вЂєР вЂ ')}: ${localizedRoleLabel(currentRole, _language)}',
                        style: AppTypography.button.copyWith(
                          color: AppColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    Text(
                      _t(
                        ru: 'Р СћР вЂўР С™Р Р€Р В©Р С’Р Р‡',
                        en: 'CURRENT',
                        kk: 'Р С’РўвЂ™Р В«Р СљР вЂќР С’РўвЂ™Р В«',
                      ),
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
                  ru: 'Р СџР В Р С›Р вЂњР В Р С’Р СљР СљР С’ Р вЂєР С›Р Р‡Р вЂєР В¬Р СњР С›Р РЋР СћР В',
                  en: 'LOYALTY PROGRAM',
                  kk: 'Р вЂєР С›Р Р‡Р вЂєР В¬Р вЂќР вЂ Р вЂєР вЂ Р С™ Р вЂР С’РўвЂ™Р вЂќР С’Р В Р вЂєР С’Р СљР С’Р РЋР В«',
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
                      label: _t(
                        ru: 'Р СџР С›Р СћР В Р С’Р В§Р вЂўР СњР С›',
                        en: 'SPENT',
                        kk: 'Р вЂ“РўВ°Р СљР РЋР С’Р вЂєР вЂќР В«',
                      ),
                      value: formatCurrency(loyalty.totalSpent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricCard(
                      label: _t(
                        ru: 'Р вЂР С›Р СњР Р€Р РЋР В«',
                        en: 'BONUSES',
                        kk: 'Р вЂР С›Р СњР Р€Р РЋР СћР С’Р В ',
                      ),
                      value: formatCurrency(loyalty.bonusBalance),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                loyalty.nextTier == null
                    ? _t(
                        ru: 'Р СљР В°Р С”РЎРѓР С‘Р СР В°Р В»РЎРЉР Р…РЎвЂ№Р в„– РЎС“РЎР‚Р С•Р Р†Р ВµР Р…РЎРЉ РЎС“Р В¶Р Вµ Р С•РЎвЂљР С”РЎР‚РЎвЂ№РЎвЂљ.',
                        en: 'Top tier already unlocked.',
                        kk: 'Р вЂўРўР€ Р В¶Р С•РўвЂњР В°РЎР‚РЎвЂ№ Р Т‘Р ВµРўР€Р С–Р ВµР в„– Р В°РЎв‚¬РЎвЂ№Р В»РўвЂњР В°Р Р….',
                      )
                    : _t(
                        ru: 'Р вЂќР С• РЎС“РЎР‚Р С•Р Р†Р Р…РЎРЏ ${loyalty.nextTier!.titleFor(_language)} Р С•РЎРѓРЎвЂљР В°Р В»Р С•РЎРѓРЎРЉ ${formatCurrency(loyalty.amountToNextTier)}.',
                        en: '${formatCurrency(loyalty.amountToNextTier)} left to reach ${loyalty.nextTier!.titleFor(_language)}.',
                        kk: '${loyalty.nextTier!.titleFor(_language)} Р Т‘Р ВµРўР€Р С–Р ВµР в„–РЎвЂ“Р Р…Р Вµ Р Т‘Р ВµР в„–РЎвЂ“Р Р… ${formatCurrency(loyalty.amountToNextTier)} РўвЂєР В°Р В»Р Т‘РЎвЂ№.',
                      ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  ru: 'Р СџР С•РЎР‚Р С•Р С– РЎРѓРЎвЂЎР С‘РЎвЂљР В°Р ВµРЎвЂљРЎРѓРЎРЏ Р С—Р С• РЎРѓРЎС“Р СР СР Вµ Р С•Р С—Р В»Р В°РЎвЂЎР ВµР Р…Р Р…РЎвЂ№РЎвЂ¦ Р С—Р С•Р С”РЎС“Р С—Р С•Р С”, Р В° Р Р…Р Вµ Р С—Р С• Р С”Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†РЎС“ Р В·Р В°Р С”Р В°Р В·Р С•Р Р†.',
                  en: 'Tiers are based on total paid spend, not on order count.',
                  kk: 'Р вЂќР ВµРўР€Р С–Р ВµР в„–Р В»Р ВµРЎР‚ РЎвЂљР В°Р С—РЎРѓРЎвЂ№РЎР‚РЎвЂ№РЎРѓ РЎРѓР В°Р Р…РЎвЂ№Р Р…Р В° Р ВµР СР ВµРЎРѓ, РЎвЂљРЈВ©Р В»Р ВµР Р…Р С–Р ВµР Р… РЎРѓР В°РЎвЂљРЎвЂ№Р С— Р В°Р В»РЎС“ РЎРѓР С•Р СР В°РЎРѓРЎвЂ№Р Р…Р В° Р В±Р В°Р в„–Р В»Р В°Р Р…РЎвЂ№РЎРѓРЎвЂљРЎвЂ№.',
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
                    ru: 'Р вЂєРЎР‹Р В±Р С‘Р СРЎвЂ№Р Вµ Р СР С•Р Т‘Р ВµР В»Р С‘',
                    en: 'Favorite Models',
                    kk: 'Р СћР В°РўР€Р Т‘Р В°РЎС“Р В»РЎвЂ№ Р СР С•Р Т‘Р ВµР В»РЎРЉР Т‘Р ВµРЎР‚',
                  ),
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
                ru: 'Р РЋР С•РЎвЂ¦РЎР‚Р В°Р Р…Р ВµР Р…Р Р…РЎвЂ№Р Вµ Р СР С•Р Т‘Р ВµР В»Р С‘ Р С—Р С•РЎРЏР Р†РЎРЏРЎвЂљРЎРѓРЎРЏ Р В·Р Т‘Р ВµРЎРѓРЎРЉ Р С‘ Р В±РЎС“Р Т‘РЎС“РЎвЂљ Р С•РЎвЂљР С”РЎР‚РЎвЂ№Р Р†Р В°РЎвЂљРЎРЉРЎРѓРЎРЏ Р С”Р В°Р С” Р С•Р В±РЎвЂ№РЎвЂЎР Р…РЎвЂ№Р Вµ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р С‘ РЎвЂљР С•Р Р†Р В°РЎР‚Р В°.',
                en: 'Saved models will appear here and open like regular product cards.',
                kk: 'Р РЋР В°РўвЂєРЎвЂљР В°Р В»РўвЂњР В°Р Р… Р СР С•Р Т‘Р ВµР В»РЎРЉР Т‘Р ВµРЎР‚ Р С•РЎРѓРЎвЂ№Р Р…Р Т‘Р В° Р С—Р В°Р в„–Р Т‘Р В° Р В±Р С•Р В»Р В°Р Т‘РЎвЂ№ Р В¶РЈв„ўР Р…Р Вµ РЈв„ўР Т‘Р ВµРЎвЂљРЎвЂљР ВµР С–РЎвЂ“ РЎвЂљР В°РЎС“Р В°РЎР‚ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р В°Р В»Р В°РЎР‚РЎвЂ№ РЎРѓР С‘РЎРЏРўвЂєРЎвЂљРЎвЂ№ Р В°РЎв‚¬РЎвЂ№Р В»Р В°Р Т‘РЎвЂ№.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        if (trackedOrder != null) ...[
          const SizedBox(height: 12),
          _orderCard(
            order: trackedOrder,
            cta: _t(
              ru: 'Р С›Р СћР РЋР вЂєР вЂўР вЂќР ВР СћР В¬',
              en: 'TRACK',
              kk: 'Р вЂР С’РўС™Р В«Р вЂєР С’Р Р€',
            ),
            onTap: () => setState(() => _view = ClientView.tracking),
          ),
        ],
        const SizedBox(height: 16),
        AvishuButton(
          text: _t(
            ru: 'Р СџР С›Р В§Р вЂўР СљР Р€ AVISHU',
            en: 'WHY AVISHU',
            kk: 'Р СњР вЂўР вЂњР вЂў AVISHU',
          ),
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.arrow_outward,
          onPressed: () => context.push('/why-avishu'),
        ),
        const SizedBox(height: 16),
        AvishuButton(
          text: _t(
            ru: 'Р вЂ™Р В«Р в„ўР СћР В Р ВР вЂ” Р С’Р С™Р С™Р С’Р Р€Р СњР СћР С’',
            en: 'SIGN OUT',
            kk: 'Р С’Р С™Р С™Р С’Р Р€Р СњР СћР СћР С’Р Сњ Р РЃР В«РўвЂ™Р Р€',
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
          '${_t(ru: 'Р вЂњР вЂєР С’Р вЂ™Р СњР С’Р Р‡', en: 'HOME', kk: 'Р вЂР С’Р РЋР СћР В« Р вЂР вЂўР Сћ')} / ${seasonLabel.toUpperCase()} / ${categoryLabel.toUpperCase()} / ${product.title}',
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
            ru: 'Р ВР СњР В¤Р С›Р В Р СљР С’Р В¦Р ВР Р‡ Р С› Р СћР С›Р вЂ™Р С’Р В Р вЂў',
            en: 'PRODUCT INFO',
            kk: 'Р СћР С’Р Р€Р С’Р В  Р СћР Р€Р В Р С’Р вЂєР В« Р С’РўС™Р СџР С’Р В Р С’Р Сћ',
          ),
          rows: [
            OrderInfoRowData(
              label: _t(
                ru: 'Р С’РЎР‚РЎвЂљР С‘Р С”РЎС“Р В»',
                en: 'SKU',
                kk: 'Р С’РЎР‚РЎвЂљР С‘Р С”РЎС“Р В»',
              ),
              value: product.sku,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р СљР В°РЎвЂљР ВµРЎР‚Р С‘Р В°Р В»',
                en: 'Material',
                kk: 'Р СљР В°РЎвЂљР ВµРЎР‚Р С‘Р В°Р В»',
              ),
              value: product.material,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р РЋР С‘Р В»РЎС“РЎРЊРЎвЂљ',
                en: 'Silhouette',
                kk: 'Р РЋР С‘Р В»РЎС“РЎРЊРЎвЂљ',
              ),
              value: product.silhouette,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р В¦Р Р†Р ВµРЎвЂљ',
                en: 'Color',
                kk: 'Р СћРўР‡РЎРѓ',
              ),
              value: selectedColor,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р В Р В°Р В·Р СР ВµРЎР‚',
                en: 'Size',
                kk: 'РЈРЃР В»РЎв‚¬Р ВµР С',
              ),
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
                _t(ru: 'Р В¦Р вЂ™Р вЂўР Сћ', en: 'COLOR', kk: 'Р СћРўВ®Р РЋ'),
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
                _t(
                  ru: 'Р В Р С’Р вЂ”Р СљР вЂўР В ',
                  en: 'SIZE',
                  kk: 'РЈРЃР вЂєР РЃР вЂўР Сљ',
                ),
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
                      _t(
                        ru: 'Р В Р В°Р В·Р СР ВµРЎР‚Р Р…Р В°РЎРЏ РЎРѓР ВµРЎвЂљР С”Р В°',
                        en: 'Size Guide',
                        kk: 'РЈРЃР В»РЎв‚¬Р ВµР СР Т‘Р ВµРЎР‚ Р С”Р ВµРЎРѓРЎвЂљР ВµРЎРѓРЎвЂ“',
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
                    ru: 'Р вЂќР С’Р СћР С’ Р вЂњР С›Р СћР С›Р вЂ™Р СњР С›Р РЋР СћР В',
                    en: 'READY DATE',
                    kk: 'Р вЂќР С’Р в„ўР В«Р Сњ Р вЂР С›Р вЂєР С’Р СћР В«Р Сњ Р С™РўВ®Р СњР вЂ ',
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
                    ? _t(
                        ru: 'Р вЂ™ Р Р…Р В°Р В»Р С‘РЎвЂЎР С‘Р С‘',
                        en: 'In Stock',
                        kk: 'РўС™Р С•Р в„–Р СР В°Р Т‘Р В° Р В±Р В°РЎР‚',
                      )
                    : _t(
                        ru: 'Р СњР ВµРЎвЂљ Р Р† Р Р…Р В°Р В»Р С‘РЎвЂЎР С‘Р С‘',
                        en: 'Out of Stock',
                        kk: 'РўС™Р С•Р в„–Р СР В°Р Т‘Р В° Р В¶Р С•РўвЂє',
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
                  Flexible(flex: 4, child: _quantitySelector()),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 6,
                    child: AvishuButton(
                      text: isFavorite
                          ? _t(
                              ru: 'Р вЂ™ Р ВР вЂ”Р вЂР В Р С’Р СњР СњР С›Р Сљ',
                              en: 'IN FAVORITES',
                              kk: 'Р СћР С’РўСћР вЂќР С’Р Р€Р вЂєР В«Р вЂќР С’',
                            )
                          : _t(
                              ru: 'Р вЂ™ Р ВР вЂ”Р вЂР В Р С’Р СњР СњР С›Р вЂў',
                              en: 'ADD TO FAVORITES',
                              kk: 'Р СћР С’РўСћР вЂќР С’Р Р€Р вЂєР В«РўвЂ™Р С’ РўС™Р С›Р РЋР Р€',
                            ),
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
                    ? _t(
                        ru: 'Р СџР В Р С›Р вЂќР С›Р вЂєР вЂ“Р ВР СћР В¬ Р СџР В Р вЂўР вЂќР вЂ”Р С’Р С™Р С’Р вЂ”',
                        en: 'CONTINUE PREORDER',
                        kk: 'Р С’Р вЂєР вЂќР В«Р Сњ Р С’Р вЂєР С’ Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋР СћР В« Р вЂ“Р С’Р вЂєРўвЂ™Р С’Р РЋР СћР В«Р В Р Р€',
                      )
                    : _t(
                        ru: 'Р С›Р В¤Р С›Р В Р СљР ВР СћР В¬ Р вЂ”Р С’Р С™Р С’Р вЂ”',
                        en: 'PLACE ORDER',
                        kk: 'Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋ Р вЂР вЂўР В Р Р€',
                      ),
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
          title: _t(
            ru: 'Р С›Р СџР ВР РЋР С’Р СњР ВР вЂў',
            en: 'DESCRIPTION',
            kk: 'Р РЋР ВР СџР С’Р СћР СћР С’Р СљР С’',
          ),
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
            ru: 'Р ТђР С’Р В Р С’Р С™Р СћР вЂўР В Р ВР РЋР СћР ВР С™Р В',
            en: 'SPECIFICATIONS',
            kk: 'Р РЋР ВР СџР С’Р СћР СћР С’Р СљР С’Р вЂєР С’Р В ',
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
          title: _t(
            ru: 'Р Р€Р ТђР С›Р вЂќ',
            en: 'CARE',
            kk: 'Р С™РўВ®Р СћР вЂ Р Сљ',
          ),
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
                      'РІР‚Сћ $rule',
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
            ru: 'Р РЋР С›Р РЋР СћР С’Р вЂ™ Р вЂ”Р С’Р С™Р С’Р вЂ”Р С’',
            en: 'ORDER SUMMARY',
            kk: 'Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋ РўС™РўВ°Р В Р С’Р СљР В«',
          ),
          rows: [
            OrderInfoRowData(
              label: _t(
                ru: 'Р ВР В·Р Т‘Р ВµР В»Р С‘Р Вµ',
                en: 'Product',
                kk: 'Р вЂРўВ±Р в„–РЎвЂ№Р С',
              ),
              value: product.title,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р В¦Р Р†Р ВµРЎвЂљ',
                en: 'Color',
                kk: 'Р СћРўР‡РЎРѓ',
              ),
              value: _selectedColor ?? product.defaultColor,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р В Р В°Р В·Р СР ВµРЎР‚',
                en: 'Size',
                kk: 'РЈРЃР В»РЎв‚¬Р ВµР С',
              ),
              value: _selectedSize ?? product.defaultSize,
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р С™Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†Р С•',
                en: 'Quantity',
                kk: 'Р РЋР В°Р Р…РЎвЂ№',
              ),
              value: '$_quantity',
            ),
            OrderInfoRowData(
              label: _t(
                ru: 'Р РЋРЎвЂљР С•Р С‘Р СР С•РЎРѓРЎвЂљРЎРЉ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р С‘',
                en: 'Unit Price',
                kk: 'Р вЂРЎвЂ“РЎР‚Р В»РЎвЂ“Р С” Р В±Р В°РўвЂњР В°РЎРѓРЎвЂ№',
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
          title: _t(
            ru: 'Р ВР СћР С›Р вЂњР С›',
            en: 'TOTAL',
            kk: 'Р вЂ“Р ВР В«Р СњР В«',
          ),
          rows: _checkoutRows(product, pricing: pricing, loyalty: loyalty),
        ),
        const SizedBox(height: 18),
        AvishuButton(
          text: _t(
            ru: 'Р СџР вЂўР В Р вЂўР в„ўР СћР В Р С™ Р С›Р СџР вЂєР С’Р СћР вЂў',
            en: 'GO TO PAYMENT',
            kk: 'Р СћРЈРЃР вЂєР вЂўР СљР вЂњР вЂў РЈРЃР СћР Р€',
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
    final profile = ref.read(currentUserProfileProvider).value;
    final orders =
        ref.read(clientOrdersProvider(clientId)).value ?? const <OrderModel>[];
    final pricing = _checkoutPricing(product, profile: profile, orders: orders);
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
          ru: 'Р вЂ”Р В°Р С—Р С•Р В»Р Р…Р С‘РЎвЂљР Вµ Р С–Р С•РЎР‚Р С•Р Т‘ Р С‘ Р В°Р Т‘РЎР‚Р ВµРЎРѓ Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”Р С‘.',
          en: 'Fill in the city and delivery address.',
          kk: 'РўС™Р В°Р В»Р В° Р СР ВµР Р… Р В¶Р ВµРЎвЂљР С”РЎвЂ“Р В·РЎС“ Р СР ВµР С”Р ВµР Р…Р В¶Р В°Р в„–РЎвЂ№Р Р… РЎвЂљР С•Р В»РЎвЂљРЎвЂ№РЎР‚РЎвЂ№РўР€РЎвЂ№Р В·.',
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
          ru: 'Р СџРЎР‚Р С•Р Р†Р ВµРЎР‚РЎРЉРЎвЂљР Вµ Р Т‘Р В°Р Р…Р Р…РЎвЂ№Р Вµ Р В±Р В°Р Р…Р С”Р С•Р Р†РЎРѓР С”Р С•Р в„– Р С”Р В°РЎР‚РЎвЂљРЎвЂ№.',
          en: 'Check the bank card details.',
          kk: 'Р вЂР В°Р Р…Р С” Р С”Р В°РЎР‚РЎвЂљР В°РЎРѓРЎвЂ№Р Р…РЎвЂ№РўР€ Р Т‘Р ВµРЎР‚Р ВµР С”РЎвЂљР ВµРЎР‚РЎвЂ“Р Р… РЎвЂљР ВµР С”РЎРѓР ВµРЎР‚РЎвЂ“РўР€РЎвЂ“Р В·.',
        ),
      );
      return false;
    }
    return true;
  }

  String _checkoutAddressTitle() {
    return _t(ru: 'РђРґСЂРµСЃ РґРѕСЃС‚Р°РІРєРё', en: 'DELIVERY ADDRESS');
  }

  String _checkoutCityLabel() {
    return _t(ru: 'Р“РѕСЂРѕРґ', en: 'City');
  }

  String _checkoutAddressLabel() {
    return _t(ru: 'РђРґСЂРµСЃ', en: 'Address');
  }

  String _checkoutApartmentLabel() {
    return _t(ru: 'РљРІР°СЂС‚РёСЂР° / РѕС„РёСЃ', en: 'Apartment / Office');
  }

  String _checkoutCommentLabel() {
    return _t(
      ru: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№ Рє Р·Р°РєР°Р·Сѓ',
      en: 'Order Comment',
    );
  }

  String _checkoutLoyaltyTitle() {
    return _t(
      ru: 'РџСЂРµРёРјСѓС‰РµСЃС‚РІР° Р»РѕСЏР»СЊРЅРѕСЃС‚Рё',
      en: 'LOYALTY BENEFITS',
    );
  }

  String _checkoutDiscountTitle() {
    return _t(
      ru: 'РџСЂРёРјРµРЅРёС‚СЊ СЃРєРёРґРєСѓ СѓСЂРѕРІРЅСЏ',
      en: 'Apply tier discount',
    );
  }

  String _checkoutDiscountSubtitle(LoyaltyProfileSnapshot loyalty) {
    return _t(
      ru: 'РЎРµР№С‡Р°СЃ РґРѕСЃС‚СѓРїРЅРѕ ${_discountLabel(loyalty.currentTier.discountRate)} РЅР° СЌС‚РѕС‚ Р·Р°РєР°Р·.',
      en: '${_discountLabel(loyalty.currentTier.discountRate)} is available for this order.',
    );
  }

  String _checkoutBonusTitle() {
    return _t(
      ru: 'РСЃРїРѕР»СЊР·РѕРІР°С‚СЊ Р±РѕРЅСѓСЃРЅС‹Р№ Р±Р°Р»Р°РЅСЃ',
      en: 'Use bonus balance',
    );
  }

  String _checkoutBonusSubtitle(LoyaltyProfileSnapshot loyalty) {
    return _t(
      ru: 'Р”РѕСЃС‚СѓРїРЅРѕ ${formatCurrency(loyalty.bonusBalance)} РґР»СЏ РѕРїР»Р°С‚С‹.',
      en: '${formatCurrency(loyalty.bonusBalance)} can be applied to the payment.',
    );
  }

  String _checkoutMethodTitle() {
    return _t(ru: 'РЎРїРѕСЃРѕР± РїРѕР»СѓС‡РµРЅРёСЏ', en: 'FULFILLMENT METHOD');
  }

  String _checkoutMethodLabel() {
    return _t(ru: 'РЎРїРѕСЃРѕР±', en: 'METHOD');
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
      ru: 'Р–РґС‘Рј СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёСЋ Р·Р°РєР°Р·Р°.',
      en: 'Waiting for order synchronization.',
    );
  }

  String _trackingOrderHeading(OrderModel order) {
    return '${_t(ru: 'Р—Р°РєР°Р·', en: 'ORDER')} #${order.shortId}';
  }

  String _trackingStatusLine(OrderModel order) {
    return '${_t(ru: 'РЎС‚Р°С‚СѓСЃ', en: 'STATUS')} / ${order.status.clientLabelFor(_language)}';
  }

  String _trackingDetailsTitle() {
    return _t(ru: 'Р”РµС‚Р°Р»Рё Р·Р°РєР°Р·Р°', en: 'ORDER DETAILS');
  }

  String _trackingClientCommentTitle() {
    return _t(
      ru: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№ РєР»РёРµРЅС‚Р°',
      en: 'CLIENT COMMENT',
    );
  }

  String _trackingCommentLabel() {
    return _t(ru: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№', en: 'Comment');
  }

  String _trackingFranchiseNoteTitle() {
    return _t(
      ru: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№ С„СЂР°РЅС€РёР·С‹',
      en: 'FRANCHISE NOTE',
    );
  }

  String _trackingStatusFieldLabel() {
    return _t(ru: 'РЎС‚Р°С‚СѓСЃ', en: 'Status');
  }

  String _trackingFactoryNoteTitle() {
    return _t(
      ru: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№ РїСЂРѕРёР·РІРѕРґСЃС‚РІР°',
      en: 'FACTORY NOTE',
    );
  }

  String _trackingFactoryLabel() {
    return _t(ru: 'РџСЂРѕРёР·РІРѕРґСЃС‚РІРѕ', en: 'Factory');
  }

  String _trackingBackLabel() {
    return _t(ru: 'РќР°Р·Р°Рґ', en: 'BACK');
  }

  String _trackingCatalogLabel() {
    return _t(ru: 'РљР°С‚Р°Р»РѕРі', en: 'CATALOG');
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
      '${_t(ru: 'Р В¦Р Р†Р ВµРЎвЂљ', en: 'Color')}: ${_selectedColor ?? product.defaultColor}',
      '${_t(ru: 'Р С™Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†Р С•', en: 'Quantity')}: $_quantity',
      if (pricing.discountAmount > 0)
        '${_t(ru: 'Р РЋР С”Р С‘Р Т‘Р С”Р В° Р В»Р С•РЎРЏР В»РЎРЉР Р…Р С•РЎРѓРЎвЂљР С‘', en: 'Loyalty discount', kk: 'Р С’Р Т‘Р В°Р В»Р Т‘РЎвЂ№РўвЂє Р В¶Р ВµРўР€РЎвЂ“Р В»Р Т‘РЎвЂ“Р С–РЎвЂ“')}: ${formatCurrency(pricing.discountAmount)}',
      if (pricing.bonusRedeemed > 0)
        '${_t(ru: 'Р РЋР С—Р С‘РЎРѓР В°Р Р…Р С• Р В±Р С•Р Р…РЎС“РЎРѓР С•Р Р†', en: 'Bonuses used', kk: 'Р СџР В°Р в„–Р Т‘Р В°Р В»Р В°Р Р…РЎвЂ№Р В»РўвЂњР В°Р Р… Р В±Р С•Р Р…РЎС“РЎРѓ')}: ${formatCurrency(pricing.bonusRedeemed)}',
      if (pricing.earnedBonus > 0)
        '${_t(ru: 'Р СњР В°РЎвЂЎР С‘РЎРѓР В»Р С‘РЎвЂљРЎРѓРЎРЏ Р В±Р С•Р Р…РЎС“РЎРѓР В°Р СР С‘', en: 'Bonuses to earn', kk: 'Р СћРўР‡РЎРѓР ВµРЎвЂљРЎвЂ“Р Р… Р В±Р С•Р Р…РЎС“РЎРѓ')}: ${formatCurrency(pricing.earnedBonus)}',
      if (customerNote.isNotEmpty)
        '${_t(ru: 'Р С™Р С•Р СР СР ВµР Р…РЎвЂљР В°РЎР‚Р С‘Р в„– Р С”Р В»Р С‘Р ВµР Р…РЎвЂљР В°', en: 'Client Comment', kk: 'Р С™Р В»Р С‘Р ВµР Р…РЎвЂљ Р С—РЎвЂ“Р С”РЎвЂ“РЎР‚РЎвЂ“')}: $customerNote',
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
        label: _t(ru: 'Р ВР В·Р Т‘Р ВµР В»Р С‘Р Вµ', en: 'Product'),
        value: product.title,
      ),
      OrderInfoRowData(
        label: _t(ru: 'Р В¦Р Р†Р ВµРЎвЂљ', en: 'Color'),
        value: _selectedColor ?? product.defaultColor,
      ),
      OrderInfoRowData(
        label: _t(ru: 'Р В Р В°Р В·Р СР ВµРЎР‚', en: 'Size'),
        value: _selectedSize ?? product.defaultSize,
      ),
      OrderInfoRowData(
        label: _t(
          ru: 'Р С™Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†Р С•',
          en: 'Quantity',
        ),
        value: '$_quantity',
      ),
      OrderInfoRowData(
        label: _t(ru: 'Р РЋРЎвЂљР С•Р С‘Р СР С•РЎРѓРЎвЂљРЎРЉ', en: 'Subtotal'),
        value: formatCurrency(pricing.subtotal),
      ),
      OrderInfoRowData(
        label: _t(ru: 'Р вЂќР С•РЎРѓРЎвЂљР В°Р Р†Р С”Р В°', en: 'Delivery'),
        value:
            '${_deliveryMethod.labelFor(_language)} / ${formatCurrency(pricing.deliveryFee)}',
      ),
      if (pricing.courierSavings > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Р В­Р С”Р С•Р Р…Р С•Р СР С‘РЎРЏ Р Р…Р В° Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”Р Вµ',
            en: 'Courier savings',
            kk: 'Р вЂ“Р ВµРЎвЂљР С”РЎвЂ“Р В·РЎС“ РўР‡Р Р…Р ВµР СРЎвЂ“',
          ),
          value: '- ${formatCurrency(pricing.courierSavings)}',
        ),
      if (pricing.discountAmount > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Р РЋР С”Р С‘Р Т‘Р С”Р В° РЎС“РЎР‚Р С•Р Р†Р Р…РЎРЏ',
            en: 'Tier discount',
            kk: 'Р вЂќР ВµРўР€Р С–Р ВµР в„– Р В¶Р ВµРўР€РЎвЂ“Р В»Р Т‘РЎвЂ“Р С–РЎвЂ“',
          ),
          value: '- ${formatCurrency(pricing.discountAmount)}',
        ),
      if (pricing.bonusRedeemed > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Р РЋР С—Р С‘РЎРѓР В°Р Р…Р С• Р В±Р С•Р Р…РЎС“РЎРѓР С•Р Р†',
            en: 'Bonuses used',
            kk: 'Р СџР В°Р в„–Р Т‘Р В°Р В»Р В°Р Р…РЎвЂ№Р В»РўвЂњР В°Р Р… Р В±Р С•Р Р…РЎС“РЎРѓ',
          ),
          value: '- ${formatCurrency(pricing.bonusRedeemed)}',
        ),
      if (product.preorder && _selectedDate != null)
        OrderInfoRowData(
          label: _t(
            ru: 'Р вЂќР В°РЎвЂљР В° Р С–Р С•РЎвЂљР С•Р Р†Р Р…Р С•РЎРѓРЎвЂљР С‘',
            en: 'Ready Date',
          ),
          value: formatDate(_selectedDate!),
        ),
      if (pricing.earnedBonus > 0)
        OrderInfoRowData(
          label: _t(
            ru: 'Р вЂ™Р ВµРЎР‚Р Р…Р ВµРЎвЂљРЎРѓРЎРЏ Р В±Р С•Р Р…РЎС“РЎРѓР В°Р СР С‘',
            en: 'Bonuses to earn',
            kk: 'Р вЂР С•Р Р…РЎС“РЎРѓР С—Р ВµР Р… РўвЂєР В°Р в„–РЎвЂљР В°Р Т‘РЎвЂ№',
          ),
          value: formatCurrency(pricing.earnedBonus),
        ),
      OrderInfoRowData(
        label: _t(
          ru: 'Р ВРЎвЂљР С•Р С–Р С•',
          en: 'Total',
          kk: 'Р вЂ“Р С‘РЎвЂ№Р Р…РЎвЂ№',
        ),
        value: formatCurrency(pricing.total),
      ),
    ];
  }

  List<_DeliveryAddressPreset>
  get _deliveryAddressPresets => const <_DeliveryAddressPreset>[
    _DeliveryAddressPreset(
      labelRu: 'Р вЂќР С•Р С / Р вЂќР С•РЎРѓРЎвЂљРЎвЂ№Р С”',
      labelEn: 'Home / Dostyk',
      labelKk: 'РўВ®Р в„– / Р вЂќР С•РЎРѓРЎвЂљРЎвЂ№РўвЂє',
      city: 'Р С’Р В»Р СР В°РЎвЂљРЎвЂ№',
      address: 'Р С—РЎР‚. Р вЂќР С•РЎРѓРЎвЂљРЎвЂ№Р С”, 25',
      apartment: '12',
    ),
    _DeliveryAddressPreset(
      labelRu: 'Esentai',
      labelEn: 'Esentai',
      labelKk: 'Esentai',
      city: 'Р С’Р В»Р СР В°РЎвЂљРЎвЂ№',
      address: 'Esentai Mall',
      apartment: 'Boutique',
    ),
    _DeliveryAddressPreset(
      labelRu: 'Mega Alma-Ata',
      labelEn: 'Mega Alma-Ata',
      labelKk: 'Mega Alma-Ata',
      city: 'Р С’Р В»Р СР В°РЎвЂљРЎвЂ№',
      address:
          'РЎС“Р В». Р В Р С•Р В·РЎвЂ№Р В±Р В°Р С”Р С‘Р ВµР Р†Р В°, 247Р С’',
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
              ? _t(
                  ru: 'Р СћР С•РЎвЂЎР С”Р В° Р Р†РЎвЂ№Р Т‘Р В°РЎвЂЎР С‘ Р В·Р В°Р С”РЎР‚Р ВµР С—Р В»Р ВµР Р…Р В°',
                  en: 'Pickup point pinned',
                )
              : _t(
                  ru: 'Р С’Р Т‘РЎР‚Р ВµРЎРѓ Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”Р С‘ Р В·Р В°Р С”РЎР‚Р ВµР С—Р В»РЎвЂР Р…',
                  en: 'Destination pinned',
                )
        : _t(
            ru: 'Р вЂќР С•Р В±Р В°Р Р†РЎРЉРЎвЂљР Вµ Р В°Р Т‘РЎР‚Р ВµРЎРѓ',
            en: 'Add destination',
          );

    final etaValue = product.preorder && _selectedDate != null
        ? formatDate(_selectedDate!)
        : isPickup
        ? _t(ru: '20 Р СљР ВР Сњ', en: '20 MIN')
        : _t(ru: '45 Р СљР ВР Сњ', en: '45 MIN');

    final note = hasDestination
        ? isPickup
              ? _t(
                  ru: 'Р С™Р В°РЎР‚РЎвЂљР В° Р С—Р С•Р С”Р В°Р В·РЎвЂ№Р Р†Р В°Р ВµРЎвЂљ Р В·Р В°Р С”РЎР‚Р ВµР С—Р В»РЎвЂР Р…Р Р…РЎС“РЎР‹ РЎвЂљР С•РЎвЂЎР С”РЎС“ РЎРѓР В°Р СР С•Р Р†РЎвЂ№Р Р†Р С•Р В·Р В°. Р СџРЎР‚Р С‘ Р С‘Р В·Р СР ВµР Р…Р ВµР Р…Р С‘Р С‘ Р В°Р Т‘РЎР‚Р ВµРЎРѓР В° Р С—РЎР‚Р ВµР Р†РЎРЉРЎР‹ Р С•Р В±Р Р…Р С•Р Р†Р С‘РЎвЂљРЎРѓРЎРЏ РЎРѓРЎР‚Р В°Р В·РЎС“.',
                  en: 'The map shows the selected pickup point. Update the address fields and the preview will refresh instantly.',
                )
              : _t(
                  ru: 'Р СљР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљ Р С—Р С•РЎРѓРЎвЂљРЎР‚Р С•Р ВµР Р… Р Р…Р В° Р С•РЎРѓР Р…Р С•Р Р†Р Вµ Р Р†Р Р†Р ВµР Т‘РЎвЂР Р…Р Р…Р С•Р С–Р С• Р С–Р С•РЎР‚Р С•Р Т‘Р В° Р С‘ Р В°Р Т‘РЎР‚Р ВµРЎРѓР В°. Р вЂ™РЎвЂ№ Р СР С•Р В¶Р ВµРЎвЂљР Вµ Р С‘Р В·Р СР ВµР Р…Р С‘РЎвЂљРЎРЉ Р С—Р С•Р В»РЎРЏ Р Р†РЎР‚РЎС“РЎвЂЎР Р…РЎС“РЎР‹ Р Р† Р В»РЎР‹Р В±Р С•Р в„– Р СР С•Р СР ВµР Р…РЎвЂљ.',
                  en: 'The route is built from the current city and address fields. You can still type your own destination at any time.',
                )
        : _t(
            ru: 'Р вЂ™Р Р†Р ВµР Т‘Р С‘РЎвЂљР Вµ Р С–Р С•РЎР‚Р С•Р Т‘ Р С‘ Р В°Р Т‘РЎР‚Р ВµРЎРѓ Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”Р С‘, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р С”Р В°РЎР‚РЎвЂљР В° РЎРѓРЎР‚Р В°Р В·РЎС“ Р С—Р С•Р С”Р В°Р В·Р В°Р В»Р В° РЎвЂљР С•РЎвЂЎР С”РЎС“ Р Р…Р В°Р В·Р Р…Р В°РЎвЂЎР ВµР Р…Р С‘РЎРЏ.',
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
      sectionLabel: _t(
        ru: 'Р С™Р С’Р В Р СћР С’ Р вЂќР С›Р РЋР СћР С’Р вЂ™Р С™Р В',
        en: 'DELIVERY MAP',
      ),
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

      statusLabel: _t(ru: 'Р РЋР СћР С’Р СћР Р€Р РЋ', en: 'STATUS'),
      statusValue: resolvedStatusValue,
      etaLabel: product.preorder && _selectedDate != null
          ? _t(
              ru: 'Р вЂќР С’Р СћР С’ Р вЂњР С›Р СћР С›Р вЂ™Р СњР С›Р РЋР СћР В',
              en: 'READY DATE',
            )
          : _t(
              ru: 'Р С›Р вЂ“Р ВР вЂќР С’Р вЂўР СљР С›Р вЂў Р вЂ™Р В Р вЂўР СљР Р‡',
              en: 'EXPECTED TIME',
            ),
      etaValue: etaValue,
      locationLabel: _t(ru: 'Р вЂєР С›Р С™Р С’Р В¦Р ВР Р‡', en: 'LOCATION'),
      locationValue: _composeDeliveryLocation(city, address, apartment),
      amountLabel: _t(ru: 'Р ВР СћР С›Р вЂњР С›', en: 'TOTAL'),
      amountValue: formatCurrency(_totalPrice(product)),
      helperText: resolvedNote,
      footerLabel: isPickup
          ? _t(ru: 'MAP / PICKUP SNAPSHOT', en: 'MAP / PICKUP SNAPSHOT')
          : _t(ru: 'MAP / ADDRESS SNAPSHOT', en: 'MAP / ADDRESS SNAPSHOT'),
      modeLabel: isPickup
          ? _t(ru: 'PICKUP MODE', en: 'PICKUP MODE')
          : _t(ru: 'ROUTE PREVIEW', en: 'ROUTE PREVIEW'),
      cityLabel:
          (city.isEmpty ? _t(ru: 'Р вЂњР С›Р В Р С›Р вЂќ', en: 'CITY') : city)
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
          ? _t(
              ru: 'Р С™Р С’Р В Р СћР С’ Р вЂ™Р В«Р вЂќР С’Р В§Р В',
              en: 'PICKUP MAP',
            )
          : _t(
              ru: 'Р С™Р С’Р В Р СћР С’ Р вЂќР С›Р РЋР СћР С’Р вЂ™Р С™Р В',
              en: 'DELIVERY MAP',
            ),
      badgeLabel: _trackingMapBadge(order),
      statusLabel: _t(ru: 'Р РЋР СћР С’Р СћР Р€Р РЋ', en: 'STATUS'),
      statusValue: _trackingMapStatus(order),
      etaLabel: _trackingEtaLabel(order),
      etaValue: _trackingEtaValue(order),
      locationLabel: isPickup
          ? _t(
              ru: 'Р СћР С›Р В§Р С™Р С’ Р вЂ™Р В«Р вЂќР С’Р В§Р В',
              en: 'PICKUP POINT',
            )
          : _t(ru: 'Р вЂєР С›Р С™Р С’Р В¦Р ВР Р‡', en: 'LOCATION'),
      locationValue: _composeDeliveryLocation(
        order.deliveryCity,
        order.deliveryAddress,
        order.apartment,
      ),
      amountLabel: _t(ru: 'Р РЋР Р€Р СљР СљР С’', en: 'TOTAL'),
      amountValue: formatCurrency(order.totalAmount),
      helperText: _trackingMapNote(order),
      footerLabel: _trackingMapFooter(order),
      modeLabel: _trackingModeTag(order),
      cityLabel:
          (order.deliveryCity.isEmpty
                  ? _t(ru: 'Р вЂњР С›Р В Р С›Р вЂќ', en: 'CITY')
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
        ru: 'Р СћР С•РЎвЂЎР С”Р В° Р Р…Р В°Р В·Р Р…Р В°РЎвЂЎР ВµР Р…Р С‘РЎРЏ Р С—Р С•РЎРЏР Р†Р С‘РЎвЂљРЎРѓРЎРЏ Р С—Р С•РЎРѓР В»Р Вµ Р Р†Р Р†Р С•Р Т‘Р В° Р В°Р Т‘РЎР‚Р ВµРЎРѓР В°.',
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
      return _t(
        ru: 'Р вЂ”Р С’Р вЂ™Р вЂўР В Р РЃР вЂўР СњР С› Р вЂ™',
        en: 'COMPLETED AT',
      );
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(
        ru: 'Р С›Р вЂР СњР С›Р вЂ™Р вЂєР вЂўР СњР ВР вЂў',
        en: 'UPDATE',
      );
    }
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(
        ru: 'Р С›Р С™Р СњР С› Р вЂ™Р В«Р вЂќР С’Р В§Р В',
        en: 'PICKUP WINDOW',
      );
    }
    return _t(
      ru: 'Р С›Р вЂ“Р ВР вЂќР С’Р вЂўР СљР С›Р вЂў Р вЂ™Р В Р вЂўР СљР Р‡',
      en: 'EXPECTED TIME',
    );
  }

  String _trackingEtaValue(OrderModel order) {
    if (order.status == OrderStatus.cancelled) {
      return _t(ru: 'Р С›Р СћР СљР вЂўР СњР РѓР Сњ', en: 'CANCELLED');
    }

    final eta = _trackingEta(order);
    if (eta == null) {
      return _t(
        ru: 'Р Р€Р СћР С›Р В§Р СњР Р‡Р вЂўР СћР РЋР Р‡',
        en: 'UPDATING',
      );
    }
    return _formatEtaStamp(eta);
  }

  String _trackingMapStatus(OrderModel order) {
    switch (order.status) {
      case OrderStatus.newOrder:
        return _t(
          ru: 'Р СљР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљ РЎвЂћР С•РЎР‚Р СР С‘РЎР‚РЎС“Р ВµРЎвЂљРЎРѓРЎРЏ',
          en: 'Route is forming',
        );
      case OrderStatus.accepted:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(
                ru: 'Р СџР С•Р Т‘Р С–Р С•РЎвЂљР С•Р Р†Р С”Р В° Р С” Р Р†РЎвЂ№Р Т‘Р В°РЎвЂЎР Вµ',
                en: 'Preparing pickup',
              )
            : _t(
                ru: 'Р СњР В°Р В·Р Р…Р В°РЎвЂЎР В°Р ВµР С Р С”РЎС“РЎР‚РЎРЉР ВµРЎР‚Р В°',
                en: 'Assigning courier',
              );
      case OrderStatus.inProduction:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(
                ru: 'Р РЋР В±Р С•РЎР‚Р С”Р В° Р В·Р В°Р С”Р В°Р В·Р В°',
                en: 'Preparing the order',
              )
            : _t(
                ru: 'Р Р€Р С—Р В°Р С”Р С•Р Р†Р С”Р В° Р С—Р ВµРЎР‚Р ВµР Т‘ Р Р†РЎвЂ№Р ВµР В·Р Т‘Р С•Р С',
                en: 'Packing before dispatch',
              );
      case OrderStatus.ready:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(
                ru: 'Р вЂњР С•РЎвЂљР С•Р Р† Р С” РЎРѓР В°Р СР С•Р Р†РЎвЂ№Р Р†Р С•Р В·РЎС“',
                en: 'Ready for pickup',
              )
            : _t(
                ru: 'Р С™РЎС“РЎР‚РЎРЉР ВµРЎР‚ Р Р† Р С—РЎС“РЎвЂљР С‘',
                en: 'Courier en route',
              );
      case OrderStatus.completed:
        return order.deliveryMethod == DeliveryMethod.pickup
            ? _t(
                ru: 'Р вЂ™РЎвЂ№Р Т‘Р В°Р Р…Р С• Р С”Р В»Р С‘Р ВµР Р…РЎвЂљРЎС“',
                en: 'Picked up',
              )
            : _t(
                ru: 'Р вЂќР С•РЎРѓРЎвЂљР В°Р Р†Р В»Р ВµР Р…Р С•',
                en: 'Delivered',
              );
      case OrderStatus.cancelled:
        return _t(
          ru: 'Р вЂ”Р В°Р С”Р В°Р В· Р С•РЎвЂљР СР ВµР Р…РЎвЂР Р…',
          en: 'Order cancelled',
        );
    }
  }

  String _trackingMapBadge(OrderModel order) {
    if (order.status == OrderStatus.completed) {
      return _t(ru: 'Р вЂ”Р С’Р вЂ™Р вЂўР В Р РЃР РѓР Сњ', en: 'COMPLETE');
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(ru: 'Р С’Р В Р ТђР ВР вЂ™', en: 'ARCHIVED');
    }
    if (order.deliveryMethod == DeliveryMethod.pickup &&
        order.status == OrderStatus.ready) {
      return _t(
        ru: 'Р вЂ™Р В«Р вЂќР С’Р В§Р С’ Р С›Р СћР С™Р В Р В«Р СћР С’',
        en: 'PICKUP OPEN',
      );
    }
    if (order.deliveryMethod == DeliveryMethod.courier &&
        order.status == OrderStatus.ready) {
      return _t(ru: 'LIVE UPDATE', en: 'LIVE UPDATE');
    }
    return _t(
      ru: 'Р РЋР ВР СњР ТђР В Р С›Р СњР ВР вЂ”Р С’Р В¦Р ВР Р‡',
      en: 'SYNCED',
    );
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
        ru: 'Р вЂќР С•РЎРѓРЎвЂљР В°Р Р†Р С”Р В° Р В·Р В°Р Р†Р ВµРЎР‚РЎв‚¬Р ВµР Р…Р В°. Р СњР В° Р С”Р В°РЎР‚РЎвЂљР Вµ РЎРѓР С•РЎвЂ¦РЎР‚Р В°Р Р…РЎвЂР Р… РЎвЂћР С‘Р Р…Р В°Р В»РЎРЉР Р…РЎвЂ№Р в„– Р СР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљ Р С‘ Р С‘РЎвЂљР С•Р С–Р С•Р Р†Р В°РЎРЏ РЎРѓРЎС“Р СР СР В° Р В·Р В°Р С”Р В°Р В·Р В° Р Р† РЎвЂљР ВµР Р…Р С–Р Вµ.',
        en: 'The delivery is complete. The map keeps the final route and the total order amount in tenge.',
      );
    }
    if (order.status == OrderStatus.cancelled) {
      return _t(
        ru: 'Р вЂ”Р В°Р С”Р В°Р В· Р С•РЎвЂљР СР ВµР Р…РЎвЂР Р…, Р С—Р С•РЎРЊРЎвЂљР С•Р СРЎС“ live-Р СР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљ Р В±Р С•Р В»РЎРЉРЎв‚¬Р Вµ Р Р…Р Вµ Р С•Р В±Р Р…Р С•Р Р†Р В»РЎРЏР ВµРЎвЂљРЎРѓРЎРЏ.',
        en: 'The order was cancelled, so the live route is no longer updating.',
      );
    }
    if (order.deliveryMethod == DeliveryMethod.pickup) {
      return _t(
        ru: 'Р СћР С•РЎвЂЎР С”Р В° Р Р†РЎвЂ№Р Т‘Р В°РЎвЂЎР С‘ Р В·Р В°Р С”РЎР‚Р ВµР С—Р В»Р ВµР Р…Р В° Р Р† Р В·Р В°Р С”Р В°Р В·Р Вµ. Р С™Р В°Р С” РЎвЂљР С•Р В»РЎРЉР С”Р С• Р С‘Р В·Р Т‘Р ВµР В»Р С‘Р Вµ Р В±РЎС“Р Т‘Р ВµРЎвЂљ Р С–Р С•РЎвЂљР С•Р Р†Р С•, Р С•Р С”Р Р…Р С• РЎРѓР В°Р СР С•Р Р†РЎвЂ№Р Р†Р С•Р В·Р В° Р С•РЎРѓРЎвЂљР В°Р Р…Р ВµРЎвЂљРЎРѓРЎРЏ Р В·Р Т‘Р ВµРЎРѓРЎРЉ.',
        en: 'The pickup point is fixed in the order. Once the garment is ready, the pickup window will stay visible here.',
      );
    }
    if (order.status == OrderStatus.ready) {
      return _t(
        ru: 'Р С™РЎС“РЎР‚РЎРЉР ВµРЎР‚ РЎС“Р В¶Р Вµ Р Р…Р В° Р СР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљР Вµ. ETA Р С•Р В±Р Р…Р С•Р Р†Р В»РЎРЏР ВµРЎвЂљРЎРѓРЎРЏ Р С•РЎвЂљ Р С—Р С•РЎРѓР В»Р ВµР Т‘Р Р…Р ВµР в„– Р С—Р ВµРЎР‚Р ВµР Т‘Р В°РЎвЂЎР С‘ Р В·Р В°Р С”Р В°Р В·Р В° Р Р† Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”РЎС“.',
        en: 'The courier is already on the route. ETA updates from the latest handoff to delivery.',
      );
    }
    return _t(
      ru: 'Р СљР В°РЎР‚РЎв‚¬РЎР‚РЎС“РЎвЂљ Р С—Р С•Р Т‘Р С–Р С•РЎвЂљР С•Р Р†Р В»Р ВµР Р… Р В·Р В°РЎР‚Р В°Р Р…Р ВµР Вµ: Р С”Р В°Р С” РЎвЂљР С•Р В»РЎРЉР С”Р С• Р В·Р В°Р С”Р В°Р В· Р С—Р ВµРЎР‚Р ВµР в„–Р Т‘РЎвЂРЎвЂљ Р Р† Р Т‘Р С•РЎРѓРЎвЂљР В°Р Р†Р С”РЎС“, Р С”Р В°РЎР‚РЎвЂљР В° Р В°Р Р†РЎвЂљР С•Р СР В°РЎвЂљР С‘РЎвЂЎР ВµРЎРѓР С”Р С‘ РЎРѓРЎвЂљР В°Р Р…Р ВµРЎвЂљ live.',
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
                  '${_t(ru: 'Р РЋР С›Р В Р СћР ВР В Р С›Р вЂ™Р С’Р СћР В¬', en: 'SORT', kk: 'Р РЋРўВ°Р В Р В«Р СџР СћР С’Р Р€')}: ${_sortOption.labelFor(_language).toUpperCase()}',
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
          _t(
            ru: 'Р В Р С’Р вЂ”Р СљР вЂўР В  Р С™Р С’Р В Р СћР С›Р В§Р вЂўР С™',
            en: 'CARD SIZE',
            kk: 'Р С™Р С’Р В Р СћР С›Р В§Р С™Р С’ РЈРЃР вЂєР РЃР вЂўР СљР вЂ ',
          ),
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
                          ? 'Р СљР вЂўР СњР В¬Р РЃР вЂў'
                          : size == CatalogCardSize.standard
                          ? 'Р вЂР С’Р вЂєР С’Р СњР РЋ'
                          : 'Р С™Р В Р Р€Р СџР СњР вЂўР вЂў', en: size == CatalogCardSize.compact
                          ? 'SMALL'
                          : size == CatalogCardSize.standard
                          ? 'BALANCED'
                          : 'LARGE', kk: size == CatalogCardSize.compact
                          ? 'Р С™Р вЂ Р РЃР вЂ Р В Р вЂўР С™'
                          : size == CatalogCardSize.standard
                          ? 'Р СћР вЂўРўСћР вЂњР вЂўР В Р вЂ Р вЂєР вЂњР вЂўР Сњ'
                          : 'Р вЂ Р В Р вЂ Р В Р вЂўР С™')}',
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
                label: _t(
                  ru: 'Р вЂ™РЎРѓР Вµ',
                  en: 'All',
                  kk: 'Р вЂР В°РЎР‚Р В»РЎвЂ№РўвЂњРЎвЂ№',
                ),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
          ),
          Text(
            _quantity.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: () => setState(() => _quantity++),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            visualDensity: VisualDensity.compact,
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
                    child: _metaChip(
                      _t(
                        ru: 'Р СњР С•Р Р†Р С‘Р Р…Р С”Р В°',
                        en: 'New',
                        kk: 'Р вЂ“Р В°РўР€Р В°',
                      ),
                    ),
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
                  ru: '${product.colors.length} РЎвЂ Р Р†Р ВµРЎвЂљР В°',
                  en: '${product.colors.length} colors',
                  kk: '${product.colors.length} РЎвЂљРўР‡РЎРѓ',
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
                  '${_t(ru: 'Р вЂ”Р С’Р С™Р С’Р вЂ”', en: 'ORDER', kk: 'Р СћР С’Р СџР РЋР В«Р В Р В«Р РЋ')} #${order.shortId}',
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
                          _t(
                            ru: 'Р В Р С’Р вЂ”Р вЂќР вЂўР вЂєР В« Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњР С’',
                            en: 'CATALOG SECTIONS',
                            kk: 'Р С™Р С’Р СћР С’Р вЂєР С›Р вЂњ Р вЂРЈРЃР вЂєР вЂ Р СљР вЂќР вЂўР В Р вЂ ',
                          ),
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            ru: 'Р вЂРЎвЂ№РЎРѓРЎвЂљРЎР‚РЎвЂ№Р в„– Р С—Р ВµРЎР‚Р ВµРЎвЂ¦Р С•Р Т‘ Р С—Р С• Р С”Р С•Р В»Р В»Р ВµР С”РЎвЂ Р С‘РЎРЏР С Р Р† Р СР С•Р В±Р С‘Р В»РЎРЉР Р…Р С•Р в„– Р В°Р Т‘Р В°Р С—РЎвЂљР В°РЎвЂ Р С‘Р С‘.',
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
                          text: _t(
                            ru: 'Р СњР С’Р РЋР СћР В Р С›Р в„ўР С™Р В',
                            en: 'SETTINGS',
                          ),
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
                                  _t(
                                    ru: 'Р В Р С’Р вЂ”Р СљР вЂўР В Р СњР С’Р Р‡ Р РЋР вЂўР СћР С™Р С’',
                                    en: 'SIZE GUIDE',
                                  ),
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
      'Р вЂР В°Р В·Р С•Р Р†РЎвЂ№Р Вµ РЎР‚Р В°Р В·Р СР ВµРЎР‚РЎвЂ№' => _t(
        ru: 'Р вЂР С’Р вЂ”Р С›Р вЂ™Р В«Р вЂў Р В Р С’Р вЂ”Р СљР вЂўР В Р В«',
        en: 'BASE SIZES',
      ),
      'Р В Р В°Р В·Р СР ВµРЎР‚РЎвЂ№ Plus (+20% Р С” РЎРѓРЎвЂљР С•Р С‘Р СР С•РЎРѓРЎвЂљР С‘)' =>
        _t(
          ru: 'Р В Р С’Р вЂ”Р СљР вЂўР В Р В« PLUS (+20% Р С™ Р РЋР СћР С›Р ВР СљР С›Р РЋР СћР В)',
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
                          _t(
                            ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ Р С–РЎР‚РЎС“Р Т‘Р С‘',
                            en: 'Bust',
                          ),
                          group.columns.map((column) => column.chest).toList(),
                        ),
                        _measurementRow(
                          _t(
                            ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ РЎвЂљР В°Р В»Р С‘Р С‘',
                            en: 'Waist',
                          ),
                          group.columns.map((column) => column.waist).toList(),
                        ),
                        _measurementRow(
                          _t(
                            ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ Р В±Р ВµР Т‘Р ВµРЎР‚',
                            en: 'Hips',
                          ),
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
                  _t(
                    ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ Р С–РЎР‚РЎС“Р Т‘Р С‘',
                    en: 'Bust',
                  ),
                  column.chest,
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 10),
                _sizeGuideMetricRow(
                  _t(
                    ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ РЎвЂљР В°Р В»Р С‘Р С‘',
                    en: 'Waist',
                  ),
                  column.waist,
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 10),
                _sizeGuideMetricRow(
                  _t(
                    ru: 'Р С›Р В±РЎвЂ¦Р Р†Р В°РЎвЂљ Р В±Р ВµР Т‘Р ВµРЎР‚',
                    en: 'Hips',
                  ),
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
