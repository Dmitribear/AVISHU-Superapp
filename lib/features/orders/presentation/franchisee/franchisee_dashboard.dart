import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../auth/domain/app_user.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/delivery_method.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/services/order_analytics_service.dart';
import '../../../orders/domain/services/order_map_location_resolver.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/domain/enums/product_status.dart';
import '../../../products/domain/models/product_model.dart';
import '../../../products/presentation/franchisee_product_studio/franchisee_product_editor_view.dart';
import '../../../products/presentation/franchisee_product_studio/franchisee_product_studio_view.dart';
import '../../../users/data/user_profile_repository.dart';
import '../../../users/domain/models/user_profile.dart';
import '../shared/desk_help/desk_help.dart';
import '../shared/order_digital_twin_card.dart';
import '../shared/order_formatters.dart';
import '../shared/order_panels.dart';

final franchiseeOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).ordersByStatuses(const [
    OrderStatus.newOrder,
    OrderStatus.accepted,
    OrderStatus.inProduction,
    OrderStatus.ready,
  ]);
});

final franchiseeAnalyticsOrdersProvider = StreamProvider<List<OrderModel>>((
  ref,
) {
  return ref.watch(orderRepositoryProvider).franchiseeOrders();
});

final franchiseeProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return ref.watch(productRepositoryProvider).watchAllProducts();
});

enum FranchiseeTab { dashboard, queue, ready, catalog, profile }

class FranchiseeDashboard extends ConsumerStatefulWidget {
  const FranchiseeDashboard({super.key});

  @override
  ConsumerState<FranchiseeDashboard> createState() =>
      _FranchiseeDashboardState();
}

class _FranchiseeDashboardState extends ConsumerState<FranchiseeDashboard> {
  FranchiseeTab _tab = FranchiseeTab.dashboard;
  OrderModel? _selectedOrder;
  ProductModel? _selectedProduct;
  bool _isSubmitting = false;
  bool _isCourierSyncing = false;
  bool _isProductSaving = false;
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

  String get _metaLabel {
    if (_selectedOrder != null) {
      return _t(
        ru: 'ФРАНЧАЙЗИ / КАРТОЧКА',
        en: 'FRANCHISEE / DETAIL',
        kk: 'ФРАНЧАЙЗИ / КАРТОЧКА',
      );
    }
    if (_selectedProduct != null) {
      return _t(
        ru: 'ФРАНЧАЙЗИ / ТОВАР',
        en: 'FRANCHISEE / PRODUCT',
        kk: 'ФРАНЧАЙЗИ / ТАУАР',
      );
    }
    return switch (_tab) {
      FranchiseeTab.dashboard => _t(
        ru: 'ФРАНЧАЙЗИ / ЗАКАЗЫ',
        en: 'FRANCHISEE / ORDERS',
        kk: 'ФРАНЧАЙЗИ / ТАПСЫРЫСТАР',
      ),
      FranchiseeTab.queue => _t(
        ru: 'ФРАНЧАЙЗИ / ПОТОК',
        en: 'FRANCHISEE / FLOW',
        kk: 'ФРАНЧАЙЗИ / АҒЫН',
      ),
      FranchiseeTab.ready => _t(
        ru: 'ФРАНЧАЙЗИ / ГОТОВО',
        en: 'FRANCHISEE / READY',
        kk: 'ФРАНЧАЙЗИ / ДАЙЫН',
      ),
      FranchiseeTab.catalog => _t(
        ru: 'ФРАНЧАЙЗИ / ТОВАРЫ',
        en: 'FRANCHISEE / PRODUCTS',
        kk: 'ФРАНЧАЙЗИ / ТАУАР',
      ),
      FranchiseeTab.profile => _t(
        ru: 'ФРАНЧАЙЗИ / ПРОФИЛЬ',
        en: 'FRANCHISEE / PROFILE',
        kk: 'ФРАНЧАЙЗИ / ПРОФИЛЬ',
      ),
    };
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
      label: _t(ru: 'ТОВАРЫ', en: 'PRODUCTS', kk: 'ТАУАР'),
      icon: Icons.sell_outlined,
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
    final analyticsOrders =
        ref.watch(franchiseeAnalyticsOrdersProvider).value ??
        const <OrderModel>[];
    final profiles =
        ref.watch(allUserProfilesProvider).value ??
        const <String, UserProfile>{};
    final analytics = ref
        .watch(orderAnalyticsServiceProvider)
        .buildFranchiseeSnapshot(analyticsOrders);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _metaLabel,
      leadingIcon: _selectedOrder == null && _selectedProduct == null
          ? Icons.menu
          : Icons.arrow_back,
      actionIcon: null,
      currentIndex: _tab.index,
      navItems: _navItems,
      onLeadingTap: () {
        if (_selectedOrder == null) {
          if (_selectedProduct == null) {
            showAppSettingsSheet(context);
          } else {
            setState(() => _selectedProduct = null);
          }
        } else {
          setState(() => _selectedOrder = null);
        }
      },
      onActionTap: null,
      onNavSelected: (index) {
        setState(() {
          _tab = FranchiseeTab.values[index];
          _selectedOrder = null;
          _selectedProduct = null;
          if (_tab == FranchiseeTab.ready) _hasReadyBadge = false;
        });
      },
      body: ordersAsync.when(
        data: (orders) {
          final hasReady = orders.any((o) => o.status == OrderStatus.ready);
          if (hasReady && _tab != FranchiseeTab.ready && !_hasReadyBadge) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasReadyBadge = true);
            });
          } else if (!hasReady && _hasReadyBadge) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasReadyBadge = false);
            });
          }
          final products =
              ref.watch(franchiseeProductsProvider).value ??
              const <ProductModel>[];
          final selectedOrder = _resolveSelectedOrder(orders);
          final selectedProduct = _resolveSelectedProduct(products);
          return SingleChildScrollView(
            key: PageStorageKey(
              'franchisee-${_tab.index}-${_selectedOrder?.id ?? _selectedProduct?.id ?? 'none'}',
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: _selectedOrder != null
                ? _detailView(
                    selectedOrder ?? _selectedOrder!,
                    profiles: profiles,
                  )
                : _selectedProduct != null
                ? _buildProductStudioEditor(
                    selectedProduct ?? _selectedProduct!,
                  )
                : _rootView(orders, profiles: profiles, analytics: analytics),
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

  Widget _rootView(
    List<OrderModel> orders, {
    required Map<String, UserProfile> profiles,
    required FranchiseeAnalyticsSnapshot analytics,
  }) {
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
            title: _t(
              ru: 'ПАНЕЛЬ ЗАКАЗОВ',
              en: 'ORDER DASHBOARD',
              kk: 'ТАПСЫРЫСТАР ПАНЕЛІ',
            ),
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
                  formatCurrency(revenue),
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
          _analyticsCard(analytics),
          const SizedBox(height: 12),
          ...[...newOrders.take(2), ...queuedOrders.take(1)].map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
        ],
      ),
      FranchiseeTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(
            _t(ru: 'НОВЫЕ ЗАКАЗЫ', en: 'NEW ORDERS', kk: 'ЖАҢА ТАПСЫРЫСТАР'),
          ),
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
              child: _orderCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _sectionLabel(
            _t(
              ru: 'ПЕРЕДАНО В ЦЕХ',
              en: 'SENT TO FACTORY',
              kk: 'ЦЕХКЕ ЖІБЕРІЛДІ',
            ),
          ),
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
              child: _orderCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
        ],
      ),
      FranchiseeTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(
            _t(
              ru: 'ГОТОВО К ВЫДАЧЕ',
              en: 'READY FOR HANDOFF',
              kk: 'БЕРУГЕ ДАЙЫН',
            ),
          ),
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
              child: _orderCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
        ],
      ),
      FranchiseeTab.catalog => _buildProductStudioTab(),
      FranchiseeTab.profile => _buildProfileTab(),
    };
  }

  Widget _buildProfileTab() {
    final compact = ref.watch(appSettingsProvider).compactCards;
    final user = ref.watch(currentUserProvider).value;
    final orders =
        ref.watch(franchiseeOrdersProvider).value ?? const <OrderModel>[];
    final products =
        ref.watch(franchiseeProductsProvider).value ?? const <ProductModel>[];
    final priorityOrder = orders.isNotEmpty ? orders.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  ru: 'КАБИНЕТ ФРАНЧАЙЗИ',
                  en: 'FRANCHISEE DESK',
                  kk: 'ФРАНЧАЙЗИ КАБИНЕТІ',
                ),
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  ru: 'Управление заказами',
                  en: 'Order Operations',
                  kk: 'Тапсырыстарды басқару',
                ),
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
        const SizedBox(height: 12),
        _buildProfileHelpLauncher(
          compact: compact,
          user: user,
          orders: orders,
          products: products,
          priorityOrder: priorityOrder,
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
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required OrderModel? priorityOrder,
  }) {
    return DeskHelpLauncherSection(
      compact: compact,
      eyebrow: _t(
        ru: 'ИНСТРУКЦИЯ И ПОДДЕРЖКА',
        en: 'GUIDE & SUPPORT',
        kk: 'НҰСҚАУЛЫҚ ПЕН ҚОЛДАУ',
      ),
      title: _t(
        ru: 'Откройте рабочую инструкцию или чат поддержки.',
        en: 'Open the work guide or support chat.',
        kk: 'Жұмыс нұсқаулығын не қолдау чатын ашыңыз.',
      ),
      description: _t(
        ru: 'Теперь помощь не растягивает экран. Инструкция и поддержка открываются отдельными окнами, когда они действительно нужны.',
        en: 'Help no longer stretches the screen. The guide and support open separately when you actually need them.',
        kk: 'Көмек енді экранды созбайды. Нұсқаулық пен қолдау керек кезде бөлек ашылады.',
      ),
      actions: [
        DeskHelpLauncherAction(
          icon: Icons.fact_check_outlined,
          title: _t(
            ru: 'Как работать в desk',
            en: 'How to work in the desk',
            kk: 'Desk ішінде қалай жұмыс істеу керек',
          ),
          description: _t(
            ru: 'Быстрый сценарий по новым заказам, потоку и каталогу.',
            en: 'A quick guide for new orders, workflow, and the catalog.',
            kk: 'Жаңа тапсырыстар, ағым және каталог бойынша қысқа нұсқаулық.',
          ),
          actionLabel: _t(ru: 'OPEN', en: 'OPEN', kk: 'OPEN'),
          onTap: () => showDeskHelpSheet(
            context,
            eyebrow: _t(
              ru: 'КАК РАБОТАТЬ В DESK',
              en: 'HOW TO WORK IN THE DESK',
              kk: 'DESK ІШІНДЕ ҚАЛАЙ ЖҰМЫС ІСТЕУ КЕРЕК',
            ),
            title: _t(
              ru: 'Вся операционная логика собрана в одном месте.',
              en: 'All operating logic is gathered in one place.',
              kk: 'Барлық операциялық логика бір жерде жиналған.',
            ),
            description: _t(
              ru: 'Здесь можно быстро понять, как принять заказ, передать его в цех и обновить товар без отдельной админки.',
              en: 'Use this sheet to see how to accept an order, hand it to production, and update products without a separate admin panel.',
              kk: 'Осы жерден тапсырысты қабылдау, цехқа беру және тауарды бөлек админкасыз жаңарту жолын тез көруге болады.',
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
            ru: 'Чат с поддержкой',
            en: 'Support chat',
            kk: 'Қолдау чаты',
          ),
          description: _t(
            ru: 'Откройте быстрые действия и соберите сообщение для поддержки за пару секунд.',
            en: 'Open quick actions and prepare a support message in a few seconds.',
            kk: 'Жедел әрекеттерді ашып, қолдауға хабарламаны бірнеше секундта дайындаңыз.',
          ),
          actionLabel: _t(ru: 'CHAT', en: 'CHAT', kk: 'CHAT'),
          emphasized: true,
          onTap: () => showDeskHelpSheet(
            context,
            eyebrow: _t(
              ru: 'ПОМОЩЬ И ПОДДЕРЖКА',
              en: 'HELP & SUPPORT',
              kk: 'КӨМЕК ЖӘНЕ ҚОЛДАУ',
            ),
            title: _t(
              ru: 'Чат поддержки AVISHU',
              en: 'AVISHU support chat',
              kk: 'AVISHU қолдау чаты',
            ),
            description: _t(
              ru: 'Скопируйте готовое сообщение, email или номер приоритетного заказа и сразу отправьте это в поддержку.',
              en: 'Copy a ready message, your email, or the priority order number and send it to support right away.',
              kk: 'Дайын хабарламаны, email-ді немесе басым тапсырыс нөмірін көшіріп, қолдауға бірден жібере аласыз.',
            ),
            child: _buildProfileSupportSection(
              compact: compact,
              user: user,
              orders: orders,
              products: products,
              priorityOrder: priorityOrder,
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
        ru: 'КАК РАБОТАТЬ В DESK',
        en: 'HOW TO WORK IN THE DESK',
        kk: 'DESK ІШІНДЕ ҚАЛАЙ ЖҰМЫС ІСТЕУ КЕРЕК',
      ),
      title: _t(
        ru: 'Вся операционная логика собрана в одном экране.',
        en: 'All operating logic is gathered in one desk.',
        kk: 'Барлық операциялық логика бір экранға жиналған.',
      ),
      description: _t(
        ru: 'Новые заказы, текущий поток, готовые позиции и каталог работают как одна система без лишних переходов.',
        en: 'New orders, the active workflow, ready items, and the catalog work as one system without extra jumps.',
        kk: 'Жаңа тапсырыстар, ағымдағы ағын, дайын позициялар және каталог артық ауысусыз бір жүйе ретінде жұмыс істейді.',
      ),
      points: [
        DeskHelpGuidePoint(
          title: _t(
            ru: 'Берите новый заказ сразу',
            en: 'Take the new order right away',
            kk: 'Жаңа тапсырысты бірден алыңыз',
          ),
          description: _t(
            ru: 'После оплаты заказ появляется без перезагрузки, поэтому можно сразу проверить адрес, комментарий и изделие.',
            en: 'A paid order appears without reload, so you can immediately check the address, note, and garment.',
            kk: 'Төленген тапсырыс қайта жүктеусіз көрінеді, сондықтан мекенжайды, ескертпені және бұйымды бірден тексеруге болады.',
          ),
        ),
        DeskHelpGuidePoint(
          title: _t(
            ru: 'Передавайте в цех без потери деталей',
            en: 'Send to production without losing details',
            kk: 'Цехқа деректерді жоғалтпай жіберіңіз',
          ),
          description: _t(
            ru: 'После подтверждения заказ сразу уходит в поток, а клиентские и внутренние заметки остаются в карточке.',
            en: 'After confirmation the order moves into the workflow, while client and internal notes stay on the card.',
            kk: 'Растаудан кейін тапсырыс ағынға бірден өтеді, ал клиент пен ішкі жазбалар карточкада қалады.',
          ),
        ),
        DeskHelpGuidePoint(
          title: _t(
            ru: 'Обновляйте каталог без отдельной админки',
            en: 'Update the catalog without a separate admin panel',
            kk: 'Каталогты бөлек админкасыз жаңартыңыз',
          ),
          description: _t(
            ru: 'В товарах можно менять наличие, размеры, цену и галерею, не выходя из AVISHU.',
            en: 'You can update stock, sizes, price, and gallery directly inside AVISHU.',
            kk: 'Қолжетімділікті, өлшемдерді, бағаны және галереяны AVISHU ішінен жаңартуға болады.',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileFlowSection({required bool compact}) {
    return DeskHelpSystemFlowSection(
      compact: compact,
      eyebrow: _t(ru: 'СИСТЕМНЫЙ ПОТОК', en: 'SYSTEM FLOW', kk: 'ЖҮЙЕЛІК АҒЫН'),
      steps: [
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.client, _language),
          details: _t(
            ru: 'Клиент выбирает изделие, подтверждает размер, адрес и завершает оплату.',
            en: 'The client chooses the garment, confirms the size and address, and completes payment.',
            kk: 'Клиент бұйымды таңдап, өлшем мен мекенжайды растап, төлемді аяқтайды.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.franchisee, _language),
          details: _t(
            ru: 'Франчайзи видит новый заказ сразу после оплаты, проверяет детали и передаёт задачу дальше.',
            en: 'The franchisee sees the new order right after payment, checks the details, and moves the task forward.',
            kk: 'Франчайзи жаңа тапсырысты төлемнен кейін бірден көріп, деректерді тексеріп, тапсырманы келесі кезеңге жібереді.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.production, _language),
          details: _t(
            ru: 'Производство берёт заказ в работу, обновляет этапы и отмечает готовность вещи.',
            en: 'Production takes the order into work, updates stages, and marks the garment as ready.',
            kk: 'Өндіріс тапсырысты жұмысқа алып, кезеңдерді жаңартып, бұйымның дайын екенін белгілейді.',
          ),
        ),
        DeskHelpFlowStep(
          title: localizedRoleLabel(UserRole.client, _language),
          details: _t(
            ru: 'Клиент получает обновление в трекинге, видит готовность и завершает путь получением заказа.',
            en: 'The client receives the update in tracking, sees the ready status, and completes the journey by receiving the order.',
            kk: 'Клиент бақылауда жаңартуды көріп, дайын мәртебесін алады және тапсырысты алумен циклді аяқтайды.',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSupportSection({
    required bool compact,
    required AppUser? user,
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required OrderModel? priorityOrder,
  }) {
    return DeskHelpSupportSection(
      compact: compact,
      eyebrow: _t(
        ru: 'ПОМОЩЬ И ПОДДЕРЖКА',
        en: 'HELP & SUPPORT',
        kk: 'КӨМЕК ЖӘНЕ ҚОЛДАУ',
      ),
      title: _t(
        ru: 'Соберите понятное обращение без ручной подготовки.',
        en: 'Build a clear support request without manual prep.',
        kk: 'Қолдау сұрауын қолмен дайындамай-ақ жинаңыз.',
      ),
      description: _t(
        ru: 'Если нужно быстро подключить поддержку, скопируйте готовое сообщение, email или номер приоритетного заказа.',
        en: 'If you need to involve support quickly, copy a ready message, your email, or the priority order number.',
        kk: 'Қолдауды тез қосу керек болса, дайын хабарламаны, email-ді немесе басым тапсырыс нөмірін көшіріңіз.',
      ),
      actions: [
        DeskHelpSupportAction(
          title: _t(
            ru: 'Скопировать сообщение для чата',
            en: 'Copy chat message',
            kk: 'Чатқа арналған хабарламаны көшіру',
          ),
          description: _t(
            ru: 'Вставьте готовый текст в чат поддержки, чтобы сразу передать роль, email и приоритетный заказ.',
            en: 'Paste the ready text into support chat to instantly share your role, email, and priority order.',
            kk: 'Рөлді, email-ді және басым тапсырысты бірден жіберу үшін дайын мәтінді қолдау чатына қойыңыз.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            _franchiseeSupportBrief(
              userEmail: user?.email ?? '',
              orders: orders,
              products: products,
              priorityOrder: priorityOrder,
            ),
            _t(
              ru: 'Сообщение для чата скопировано.',
              en: 'Chat message copied.',
              kk: 'Чатқа арналған хабарлама көшірілді.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'Скопировать email аккаунта',
            en: 'Copy account email',
            kk: 'Аккаунт email-ін көшіру',
          ),
          description: _t(
            ru: 'Поможет поддержке быстро найти ваш рабочий профиль.',
            en: 'Helps support find your working profile quickly.',
            kk: 'Қолдау қызметіне жұмыс профиліңізді тез табуға көмектеседі.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            user?.email ?? '',
            _t(
              ru: 'Email аккаунта скопирован.',
              en: 'Account email copied.',
              kk: 'Аккаунт email-і көшірілді.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'Скопировать приоритетный заказ',
            en: 'Copy priority order',
            kk: 'Басым тапсырысты көшіру',
          ),
          description: _t(
            ru: 'Подходит, когда нужно быстро показать, по какому заказу требуется помощь.',
            en: 'Use this when you need to show which order needs help right away.',
            kk: 'Қай тапсырыс бойынша көмек керек екенін бірден көрсету қажет болса, осыны қолданыңыз.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            priorityOrder == null ? '' : '#${priorityOrder.shortId}',
            _t(
              ru: 'Номер заказа скопирован.',
              en: 'Order number copied.',
              kk: 'Тапсырыс нөмірі көшірілді.',
            ),
          ),
        ),
        DeskHelpSupportAction(
          title: _t(
            ru: 'Скопировать бриф для поддержки',
            en: 'Copy support brief',
            kk: 'Қолдау brief-ін көшіру',
          ),
          description: _t(
            ru: 'Шаблон уже включает роль, email, количество заказов и товаров.',
            en: 'The template already includes your role, email, and current order and product totals.',
            kk: 'Шаблонда рөліңіз, email және ағымдағы тапсырыс пен тауар саны бар.',
          ),
          actionLabel: _t(ru: 'COPY', en: 'COPY', kk: 'COPY'),
          onTap: () => _copyToClipboard(
            _franchiseeSupportBrief(
              userEmail: user?.email ?? '',
              orders: orders,
              products: products,
              priorityOrder: priorityOrder,
            ),
            _t(
              ru: 'Бриф для поддержки скопирован.',
              en: 'Support brief copied.',
              kk: 'Қолдау brief-і көшірілді.',
            ),
          ),
        ),
      ],
      footerText: _t(
        ru: 'Для быстрого ответа добавьте скрин карточки заказа или товара и коротко опишите, на каком шаге возникла проблема.',
        en: 'To get help faster, attach a screenshot of the order or product card and mention at which step the problem appeared.',
        kk: 'Жауапты тез алу үшін тапсырыс не тауар карточкасының скринін қосып, мәселе қай қадамда шыққанын қысқаша жазыңыз.',
      ),
    );
  }

  Widget _buildProductStudioTab() {
    final products =
        ref.watch(franchiseeProductsProvider).value ?? const <ProductModel>[];

    return FranchiseeProductStudioView(
      language: _language,
      products: products,
      onCreateProduct: () {
        setState(
          () => _selectedProduct = ProductModel(
            id: '',
            name: '',
            slug: '',
            description: '',
            shortDescription: '',
            category: '',
            material: '',
            silhouette: '',
            atelierNote: '',
            sections: const <String>[],
            colors: const <String>[],
            sizes: const <String>[],
            defaultColor: '',
            defaultSize: '',
            specifications: const <ProductSpecEntry>[],
            care: const <String>[],
            price: 0,
            currency: 'KZT',
            coverImage: '',
            gallery: const <String>[],
            isPreorderAvailable: false,
            defaultProductionDays: 0,
            status: ProductStatus.active,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      },
      onEditProduct: (product) {
        setState(() => _selectedProduct = product);
      },
    );
  }

  Widget _buildProductStudioEditor(ProductModel product) {
    final isDraftProduct = product.id.isEmpty && product.name.isEmpty;

    return FranchiseeProductEditorView(
      language: _language,
      initialProduct: isDraftProduct ? null : product,
      isSaving: _isProductSaving,
      onCancel: () {
        setState(() => _selectedProduct = null);
      },
      onSave: _saveProduct,
    );
  }

  Future<void> _saveProduct(ProductModel product) async {
    if (_isProductSaving) {
      return;
    }

    setState(() => _isProductSaving = true);
    try {
      await ref.read(productRepositoryProvider).upsertProduct(product);
      if (!mounted) {
        return;
      }
      setState(() => _selectedProduct = null);
      _showSnack(
        _t(
          ru: 'Карточка товара сохранена.',
          en: 'Product card saved.',
          kk: 'Тауар карточкасы сақталды.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProductSaving = false);
      }
    }
  }

  Widget _detailView(
    OrderModel order, {
    required Map<String, UserProfile> profiles,
  }) {
    final isNew = order.status == OrderStatus.newOrder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderDigitalTwinCard(
          order: order,
          clientDisplayName: _clientDisplayName(profiles, order),
        ),
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
          title: _t(
            ru: 'ДЕТАЛИ ЗАКАЗА',
            en: 'ORDER DETAILS',
            kk: 'ТАПСЫРЫС МӘЛІМЕТТЕРІ',
          ),
          rows: OrderSummaryRows.forOrder(order, language: _language),
        ),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(
              ru: 'КОММЕНТАРИЙ КЛИЕНТА',
              en: 'CLIENT COMMENT',
              kk: 'КЛИЕНТ ПІКІРІ',
            ),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Комментарий', en: 'Comment', kk: 'Пікір'),
                value: order.clientNote,
              ),
            ],
          ),
        ],
        if (order.status == OrderStatus.ready &&
            order.deliveryMethod == DeliveryMethod.courier) ...[
          const SizedBox(height: 12),
          _liveCourierControl(order),
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
            text: _t(
              ru: 'ЗАВЕРШИТЬ ВЫДАЧУ',
              en: 'CONFIRM HANDOFF',
              kk: 'БЕРУДІ АЯҚТАУ',
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
                  _t(
                    ru: 'ПЕРЕДАНО В ПРОИЗВОДСТВО',
                    en: 'IN FACTORY QUEUE',
                    kk: 'ӨНДІРІСКЕ ЖІБЕРІЛДІ',
                  ),
                  style: AppTypography.code,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _liveCourierControl(OrderModel order) {
    final routeReady =
        order.originLocation != null && order.destinationLocation != null;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              ru: 'LIVE COURIER CONTROL',
              en: 'LIVE COURIER CONTROL',
              kk: 'LIVE COURIER CONTROL',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              ru: 'Сразу после оформления заявки мы назначим курьера. Вы сможете отслеживать его движение на карте в режиме реального времени',
              en: 'As soon as your request is finalized, a courier will be assigned immediately. You can track their progress on the map in real-time',
              kk: 'Өтінім рәсімделген бойда біз бірден курьер тағайындаймыз. Оның қозғалысын картадан нақты уақыт режимінде бақылай аласыз',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            order.courierLocationUpdatedAt == null
                ? _t(
                    ru: 'Последняя проверка: данных пока нет',
                    en: 'Last check: no data yet',
                    kk: 'Соңғы тексеру: мәлімет әлі жоқ',
                  )
                : _t(
                    ru: 'Последняя проверка: ${_formatDateTime(order.courierLocationUpdatedAt!)}',
                    en: 'Last check: ${_formatDateTime(order.courierLocationUpdatedAt!)}',
                    kk: 'Соңғы тексеру: ${_formatDateTime(order.courierLocationUpdatedAt!)}',
                  ),
            style: AppTypography.code,
          ),
          const SizedBox(height: 12),
          if (!routeReady)
            Text(
              _t(
                ru: 'Маршрут еще не инициализирован для этого заказа.',
                en: 'The route has not been initialised for this order yet.',
                kk: 'Бұл тапсырыс үшін маршрут әлі инициализацияланбаған.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  <MapEntry<String, double>>[
                    MapEntry(_t(ru: 'СТАРТ', en: 'START', kk: 'БАСТАУ'), 0.05),
                    const MapEntry('25%', 0.25),
                    const MapEntry('50%', 0.5),
                    const MapEntry('75%', 0.75),
                    MapEntry(
                      _t(ru: 'У ДВЕРИ', en: 'AT DOOR', kk: 'ЕСІК АЛДЫНДА'),
                      0.96,
                    ),
                  ].map((entry) {
                    return AvishuButton(
                      text: entry.key,
                      variant: AvishuButtonVariant.outline,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      onPressed: _isCourierSyncing
                          ? null
                          : () => _syncCourierLocation(order, entry.value),
                    );
                  }).toList(),
            ),
        ],
      ),
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
    final valueStyle = Theme.of(context).textTheme.titleLarge;

    return _surfaceCard(
      child: SizedBox(
        height: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppTypography.eyebrow),
            const SizedBox(height: 10),
            _metricValueLabel(value, valueStyle),
          ],
        ),
      ),
    );
  }

  Widget _analyticsCard(FranchiseeAnalyticsSnapshot analytics) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              ru: 'КАК ИДУТ ЗАКАЗЫ',
              en: 'ORDER SNAPSHOT',
              kk: 'ТАПСЫРЫСТАР ҚАЛАЙ ЖҮРІП ЖАТЫР',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              ru: 'Короткая сводка без лишних деталей: кто покупает, как быстро подтверждаем и сколько в среднем занимает доставка.',
              en: 'A quick overview of who is buying, how fast orders are confirmed, and how long delivery usually takes.',
              kk: 'Артық мәтінсіз қысқа шолу: кім тапсырыс береді, қаншалықты жылдам растаймыз және жеткізу орташа қанша уақыт алады.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(
                        ru: 'Средний чек',
                        en: 'Average order',
                        kk: 'Орташа тапсырыс',
                      ),
                      formatCurrency(analytics.averageOrderValue),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(ru: 'Клиентов', en: 'Clients', kk: 'Клиенттер'),
                      '${analytics.uniqueClients}',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(
                        ru: 'Подтверждаем за',
                        en: 'Confirm in',
                        kk: 'Растау уақыты',
                      ),
                      _formatAnalyticsDuration(analytics.averageAcceptanceTime),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(
                        ru: 'Доставка в среднем',
                        en: 'Delivery takes',
                        kk: 'Жеткізу уақыты',
                      ),
                      _formatAnalyticsDuration(
                        analytics.averageCourierDeliveryTime,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            analytics.topProductName == null
                ? _t(
                    ru: 'Как только накопится история заказов, здесь появится самая популярная модель.',
                    en: 'The most requested product will appear here as soon as the order history grows.',
                    kk: 'Тапсырыс тарихы көбейген сайын мұнда ең сұранысқа ие модель көрінеді.',
                  )
                : _t(
                    ru: 'Чаще всего заказывают ${analytics.topProductName}. Повторно возвращаются ${analytics.repeatClients} клиентов, завершено ${analytics.completedOrders} заказов.',
                    en: '${analytics.topProductName} is ordered most often. ${analytics.repeatClients} clients returned for another order and ${analytics.completedOrders} orders are already completed.',
                    kk: 'Ең жиі ${analytics.topProductName} тапсырыс беріледі. ${analytics.repeatClients} клиент қайта оралды, ${analytics.completedOrders} тапсырыс аяқталды.',
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _analyticsMetricCell(String label, String value) {
    final valueStyle = Theme.of(context).textTheme.titleMedium;

    return Container(
      height: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          _metricValueLabel(value, valueStyle),
        ],
      ),
    );
  }

  Widget _metricValueLabel(String value, TextStyle? style) {
    final trimmedValue = value.trim();
    if (!trimmedValue.endsWith('₸')) {
      return Text(trimmedValue, style: style);
    }

    final amount = trimmedValue
        .substring(0, trimmedValue.length - 1)
        .trimRight();

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(amount, style: style),
          const SizedBox(width: 6),
          Text('₸', style: style),
        ],
      ),
    );
  }

  Widget _orderCard(OrderModel order, {required String clientDisplayName}) {
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
            '${_t(ru: 'Клиент', en: 'Client', kk: 'Клиент')}: $clientDisplayName',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
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

  String _clientDisplayName(
    Map<String, UserProfile> profiles,
    OrderModel order,
  ) {
    final profile = profiles[order.clientId];
    final fullName = profile?.fullName.trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName;
    }
    return _t(
      ru: 'Имя уточняется',
      en: 'Name pending',
      kk: 'Аты нақтыланып жатыр',
    );
  }

  String _formatAnalyticsDuration(Duration duration) {
    if (duration == Duration.zero) {
      return '—';
    }
    if (duration.inHours < 1) {
      return _t(
        ru: '${duration.inMinutes} мин',
        en: '${duration.inMinutes} min',
        kk: '${duration.inMinutes} мин',
      );
    }
    if (duration.inDays < 1) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      if (minutes == 0) {
        return _t(ru: '$hours ч', en: '$hours h', kk: '$hours сағ');
      }
      return _t(
        ru: '$hours ч $minutes мин',
        en: '$hours h $minutes min',
        kk: '$hours сағ $minutes мин',
      );
    }

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    if (hours == 0) {
      return _t(ru: '$days дн', en: '$days d', kk: '$days күн');
    }
    return _t(
      ru: '$days дн $hours ч',
      en: '$days d $hours h',
      kk: '$days күн $hours сағ',
    );
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

  ProductModel? _resolveSelectedProduct(List<ProductModel> products) {
    final selectedProduct = _selectedProduct;
    if (selectedProduct == null || selectedProduct.id.isEmpty) {
      return selectedProduct;
    }

    for (final product in products) {
      if (product.id == selectedProduct.id) {
        return product;
      }
    }
    return selectedProduct;
  }

  void _openOrder(OrderModel order) {
    _noteController.text = order.franchiseeNote;
    setState(() => _selectedOrder = order);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyToClipboard(String text, String message) async {
    if (text.trim().isEmpty) {
      _showSnack(
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
    _showSnack(message);
  }

  String _franchiseeSupportBrief({
    required String userEmail,
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required OrderModel? priorityOrder,
  }) {
    final accountEmail = userEmail.trim().isEmpty
        ? 'not_provided'
        : userEmail.trim();
    final priorityOrderLabel = priorityOrder == null
        ? 'not_attached'
        : '#${priorityOrder.shortId}';

    return [
      'AVISHU SUPPORT BRIEF',
      'ROLE: FRANCHISEE',
      'ACCOUNT: $accountEmail',
      'ORDERS IN DESK: ${orders.length}',
      'PRODUCTS IN STUDIO: ${products.length}',
      'PRIORITY ORDER: $priorityOrderLabel',
      'ISSUE:',
      '- What is blocked',
      '- Which screen or card is affected',
      '- Screenshot attached: yes / no',
    ].join('\n');
  }

  Future<void> _syncCourierLocation(OrderModel order, double progress) async {
    final origin = order.originLocation;
    final destination = order.destinationLocation;
    if (origin == null || destination == null) {
      return;
    }

    if (_isCourierSyncing) {
      return;
    }

    setState(() => _isCourierSyncing = true);
    try {
      final courierLocation = OrderMapLocationResolver.interpolate(
        origin,
        destination,
        progress,
      );
      await ref
          .read(orderRepositoryProvider)
          .updateCourierLocation(
            order.id,
            courierLocation: courierLocation,
            note: _noteController.text.trim(),
          );
    } finally {
      if (mounted) {
        setState(() => _isCourierSyncing = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} $hour:$minute';
  }
}
