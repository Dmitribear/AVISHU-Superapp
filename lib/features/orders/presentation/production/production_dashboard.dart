import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/providers/app_settings.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../../shared/widgets/app_settings_sheet.dart';
import '../../../../shared/widgets/avishu_mobile_frame.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/services/order_analytics_service.dart';
import '../../../users/data/user_profile_repository.dart';
import '../../../users/domain/models/user_profile.dart';
import 'dashboard_sections/production_dashboard_sections.dart';
import '../shared/desk_help/desk_help.dart';
import '../shared/order_panels.dart';

final productionAllOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).productionQueue();
});

final productionAnalyticsOrdersProvider = StreamProvider<List<OrderModel>>((
  ref,
) {
  return ref.watch(orderRepositoryProvider).allOrders();
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

  String _t({required String ru, required String en, String? kk}) {
    return tr(_language, ru: ru, en: en, kk: kk);
  }

  List<AvishuNavItem> get _navItems => [
    AvishuNavItem(
      label: _t(ru: 'ОБЗОР', en: 'OVERVIEW', kk: 'ШОЛУ'),
      icon: Icons.dashboard_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'ОЧЕРЕДЬ', en: 'QUEUE', kk: 'КЕЗЕК'),
      icon: Icons.format_list_bulleted_rounded,
    ),
    AvishuNavItem(
      label: _t(ru: 'ГОТОВО', en: 'READY', kk: 'ДАЙЫН'),
      icon: Icons.checkroom_outlined,
    ),
    AvishuNavItem(
      label: _t(ru: 'СТАНЦИЯ', en: 'STATION', kk: 'БЕКЕТ'),
      icon: Icons.precision_manufacturing_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final ordersAsync = ref.watch(productionAllOrdersProvider);
    final analyticsOrders =
        ref.watch(productionAnalyticsOrdersProvider).value ??
        const <OrderModel>[];
    final profiles =
        ref.watch(allUserProfilesProvider).value ??
        const <String, UserProfile>{};
    final analytics = ref
        .watch(orderAnalyticsServiceProvider)
        .buildProductionSnapshot(analyticsOrders);

    return AvishuMobileFrame(
      title: 'AVISHU',
      metaLabel: _selectedOrder == null
          ? _t(
              ru: 'ПРОИЗВОДСТВО / ОЧЕРЕДЬ',
              en: 'FACTORY / QUEUE',
              kk: 'ӨНДІРІС / КЕЗЕК',
            )
          : _t(
              ru: 'ПРОИЗВОДСТВО / ЗАДАЧА',
              en: 'FACTORY / TASK',
              kk: 'ӨНДІРІС / ТАПСЫРМА',
            ),
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
            key: PageStorageKey(
              'production-${_tab.index}-${_selectedOrder?.id ?? "none"}',
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: _selectedOrder != null
                ? _detailView(
                    selectedOrder ?? _selectedOrder!,
                    profiles: profiles,
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
    required ProductionAnalyticsSnapshot analytics,
  }) {
    final compact = ref.watch(appSettingsProvider).compactCards;
    final user = ref.watch(currentUserProvider).value;
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
    final openTaskLabel = _t(
      ru: 'ОТКРЫТЬ ЗАДАЧУ',
      en: 'OPEN TASK',
      kk: 'ТАПСЫРМАНЫ АШУ',
    );

    return switch (_tab) {
      ProductionTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductionHeroSection(
            compact: compact,
            eyebrow: _t(
              ru: 'АКТИВНЫХ ЗАДАЧ: ${accepted.length + inProduction.length}',
              en: 'ACTIVE TASKS: ${accepted.length + inProduction.length}',
              kk: 'БЕЛСЕНДІ ТАПСЫРМАЛАР: ${accepted.length + inProduction.length}',
            ),
            title: _t(ru: 'ЦЕХ СЕГОДНЯ', en: 'FACTORY TODAY', kk: 'ЦЕХ БҮГІН'),
            subtitle: _t(
              ru: 'На экране только очередь, текущая задача и следующий шаг.',
              en: 'Only the queue, the current task, and the next step stay on screen.',
              kk: 'Экранда тек кезек, ағымдағы тапсырма және келесі қадам қалады.',
            ),
            metrics: [
              ProductionMetricCardData(
                label: _t(ru: 'К ПОШИВУ', en: 'TO START', kk: 'БАСТАУДА'),
                value: '${accepted.length}',
              ),
              ProductionMetricCardData(
                label: _t(ru: 'В РАБОТЕ', en: 'IN WORK', kk: 'ЖҰМЫСТА'),
                value: '${inProduction.length}',
              ),
              ProductionMetricCardData(
                label: _t(ru: 'ГОТОВО', en: 'READY', kk: 'ДАЙЫН'),
                value: '${ready.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProductionTaskSection(
            sectionLabel: _t(
              ru: 'ФОКУС СЕЙЧАС',
              en: 'RIGHT NOW',
              kk: 'ҚАЗІРГІ ФОКУС',
            ),
            emptyMessage: _t(
              ru: 'Очередь пуста. Новая задача появится здесь сразу после подтверждения заказа.',
              en: 'The queue is empty. The next task will appear here as soon as an order is confirmed.',
              kk: 'Кезек бос. Жаңа тапсырма тапсырыс расталған сәтте осында шығады.',
            ),
            compact: compact,
            tasks: current == null
                ? const <ProductionTaskCardData>[]
                : <ProductionTaskCardData>[
                    _taskCardData(
                      current,
                      clientDisplayName: _clientDisplayName(profiles, current),
                      footerLabel: openTaskLabel,
                    ),
                  ],
          ),
          const SizedBox(height: 12),
          ProductionAnalyticsSection(
            sectionLabel: _t(
              ru: 'РИТМ ЦЕХА',
              en: 'FACTORY RHYTHM',
              kk: 'ЦЕХ ЫРҒАҒЫ',
            ),
            title: _t(
              ru: 'Ключевые цифры без лишнего текста.',
              en: 'Key numbers without extra text.',
              kk: 'Артық мәтінсіз негізгі сандар.',
            ),
            summary: _t(
              ru: 'Смотрим только запуск, пошив, доставку и риск задержки.',
              en: 'Only start, tailoring, delivery, and delay risk stay in view.',
              kk: 'Көз алдында тек бастау, тігу, жеткізу және кешігу қаупі қалады.',
            ),
            footerText: _t(
              ru: 'Сегодня готово ${analytics.readyToday} заказов.',
              en: '${analytics.readyToday} orders became ready today.',
              kk: 'Бүгін ${analytics.readyToday} тапсырыс дайын болды.',
            ),
            slowSectionLabel: _t(
              ru: 'ЧТО ШЬЁТСЯ ДОЛЬШЕ',
              en: 'LONGER TASKS',
              kk: 'ҰЗАҒЫРАҚ ТІГІЛЕТІНІ',
            ),
            compact: compact,
            metrics: _analyticsTileData(analytics),
            slowProducts: _slowTailoringFacts(analytics),
          ),
        ],
      ),
      ProductionTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductionTaskSection(
            sectionLabel: _t(ru: 'К ПОШИВУ', en: 'TO START', kk: 'БАСТАУДА'),
            emptyMessage: _t(
              ru: 'Новых задач в очереди пока нет.',
              en: 'No new tasks in queue yet.',
              kk: 'Кезекте жаңа тапсырма әзірге жоқ.',
            ),
            compact: compact,
            tasks: _taskCards(accepted, profiles, openTaskLabel),
          ),
          const SizedBox(height: 12),
          ProductionTaskSection(
            sectionLabel: _t(ru: 'В РАБОТЕ', en: 'IN WORK', kk: 'ЖҰМЫСТА'),
            emptyMessage: _t(
              ru: 'Как только пошив стартует, задача появится здесь.',
              en: 'As soon as production starts, the task appears here.',
              kk: 'Тігу басталған сәтте тапсырма осында шығады.',
            ),
            compact: compact,
            tasks: _taskCards(inProduction, profiles, openTaskLabel),
          ),
        ],
      ),
      ProductionTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductionTaskSection(
            sectionLabel: _t(
              ru: 'ГОТОВО К ВЫДАЧЕ',
              en: 'READY TO HANDOFF',
              kk: 'БЕРУГЕ ДАЙЫН',
            ),
            emptyMessage: _t(
              ru: 'Готовых заказов пока нет.',
              en: 'No ready orders yet.',
              kk: 'Дайын тапсырыс әзірге жоқ.',
            ),
            compact: compact,
            tasks: _taskCards(ready, profiles, openTaskLabel),
          ),
        ],
      ),
      ProductionTab.station => ProductionStationSection(
        compact: compact,
        eyebrow: _t(ru: 'РАБОЧЕЕ МЕСТО', en: 'WORKSTATION', kk: 'ЖҰМЫС ОРНЫ'),
        title: _t(
          ru: 'Планшет мастера',
          en: 'Master tablet',
          kk: 'Шебер планшеті',
        ),
        summary: _t(
          ru: 'Один экран для очереди, статуса и завершения этапа.',
          en: 'One screen for the queue, status, and stage completion.',
          kk: 'Кезекке, мәртебеге және кезеңді аяқтауға арналған бір экран.',
        ),
        roleLabel: _t(
          ru: 'Роль на текущей станции',
          en: 'Current station role',
          kk: 'Ағымдағы бекет рөлі',
        ),
        roleValue: localizedRoleLabel(UserRole.production, _language),
        guideSection: DeskHelpGuideSection(
          compact: compact,
          eyebrow: _t(
            ru: 'КАК РАБОТАТЬ',
            en: 'HOW TO WORK',
            kk: 'ҚАЛАЙ ЖҰМЫС ІСТЕУ КЕРЕК',
          ),
          title: _t(
            ru: 'Каждый шаг должен быть виден сразу.',
            en: 'Every next step should be visible at once.',
            kk: 'Әр келесі қадам бірден көрініп тұруы керек.',
          ),
          description: _t(
            ru: 'Очередь не перегружает экран и оставляет только то, что нужно мастеру сейчас.',
            en: 'The queue keeps only the information the operator needs right now.',
            kk: 'Кезек шеберге дәл қазір керек ақпаратты ғана экранда қалдырады.',
          ),
          points: [
            DeskHelpGuidePoint(
              title: _t(
                ru: 'Берите верхнюю задачу',
                en: 'Take the top task',
                kk: 'Жоғарғы тапсырманы алыңыз',
              ),
              description: _t(
                ru: 'Так очередь движется без ручной сортировки.',
                en: 'This keeps the queue moving without manual sorting.',
                kk: 'Осылай кезек қолмен сұрыптаусыз жүреді.',
              ),
            ),
            DeskHelpGuidePoint(
              title: _t(
                ru: 'Обновляйте статус сразу',
                en: 'Update status immediately',
                kk: 'Мәртебені бірден жаңартыңыз',
              ),
              description: _t(
                ru: 'Франчайзи и клиент увидят реальный этап без задержки.',
                en: 'Franchisee and client see the real stage without delay.',
                kk: 'Франчайзи мен клиент нақты кезеңді кідіріссіз көреді.',
              ),
            ),
            DeskHelpGuidePoint(
              title: _t(
                ru: 'Готово отмечайте без паузы',
                en: 'Mark ready without delay',
                kk: 'Дайынды кідіріссіз белгілеңіз',
              ),
              description: _t(
                ru: 'Это ускоряет выдачу и освобождает очередь.',
                en: 'This speeds up handoff and frees the queue.',
                kk: 'Бұл беруді жылдамдатады және кезекті босатады.',
              ),
            ),
          ],
        ),
        flowSection: DeskHelpSystemFlowSection(
          compact: compact,
          eyebrow: _t(
            ru: 'СИСТЕМНЫЙ ПОТОК',
            en: 'SYSTEM FLOW',
            kk: 'ЖҮЙЕЛІК АҒЫН',
          ),
          steps: [
            DeskHelpFlowStep(
              title: localizedRoleLabel(UserRole.client, _language),
              details: _t(
                ru: 'Клиент оформляет заказ.',
                en: 'The client places the order.',
                kk: 'Клиент тапсырыс береді.',
              ),
            ),
            DeskHelpFlowStep(
              title: localizedRoleLabel(UserRole.franchisee, _language),
              details: _t(
                ru: 'Франчайзи подтверждает и передает в цех.',
                en: 'The franchisee confirms and sends it to production.',
                kk: 'Франчайзи растап, цехқа жібереді.',
              ),
            ),
            DeskHelpFlowStep(
              title: localizedRoleLabel(UserRole.production, _language),
              details: _t(
                ru: 'Цех берет задачу и переводит ее в готово.',
                en: 'Production takes the task and moves it to ready.',
                kk: 'Цех тапсырманы алып, оны дайынға өткізеді.',
              ),
            ),
            DeskHelpFlowStep(
              title: localizedRoleLabel(UserRole.client, _language),
              details: _t(
                ru: 'Клиент получает обновление в трекинге.',
                en: 'The client sees the update in tracking.',
                kk: 'Клиент жаңартуды трекингтен көреді.',
              ),
            ),
          ],
        ),
        supportSection: DeskHelpSupportSection(
          compact: compact,
          eyebrow: _t(
            ru: 'ПОМОЩЬ И ПОДДЕРЖКА',
            en: 'HELP & SUPPORT',
            kk: 'КӨМЕК ЖӘНЕ ҚОЛДАУ',
          ),
          title: _t(
            ru: 'Подготовьте обращение за пару нажатий.',
            en: 'Prepare a support request in a few taps.',
            kk: 'Қолдау сұрауын бірнеше батырмамен дайындаңыз.',
          ),
          description: _t(
            ru: 'Если задача встала, нужные данные можно сразу скопировать.',
            en: 'If a task is blocked, the right details can be copied immediately.',
            kk: 'Тапсырма тоқтаса, керекті деректі бірден көшіруге болады.',
          ),
          actions: [
            DeskHelpSupportAction(
              title: _t(
                ru: 'Скопировать email аккаунта',
                en: 'Copy account email',
                kk: 'Аккаунт email-ын көшіру',
              ),
              description: _t(
                ru: 'Нужно для быстрого поиска рабочего аккаунта.',
                en: 'Useful for finding the working account quickly.',
                kk: 'Жұмыс аккаунтын тез табу үшін керек.',
              ),
              actionLabel: _t(ru: 'КОПИЯ', en: 'COPY', kk: 'КОПИЯ'),
              onTap: () => _copyToClipboard(
                user?.email ?? '',
                _t(
                  ru: 'Email аккаунта скопирован.',
                  en: 'Account email copied.',
                  kk: 'Аккаунт email-ы көшірілді.',
                ),
              ),
            ),
            DeskHelpSupportAction(
              title: _t(
                ru: 'Скопировать активную задачу',
                en: 'Copy active task',
                kk: 'Белсенді тапсырманы көшіру',
              ),
              description: _t(
                ru: 'Поддержка сразу увидит нужный заказ.',
                en: 'Support will see the exact order right away.',
                kk: 'Қолдау бірден керек тапсырысты көреді.',
              ),
              actionLabel: _t(ru: 'КОПИЯ', en: 'COPY', kk: 'КОПИЯ'),
              onTap: () => _copyToClipboard(
                current == null ? '' : '#${current.shortId}',
                _t(
                  ru: 'Номер задачи скопирован.',
                  en: 'Task number copied.',
                  kk: 'Тапсырма нөмірі көшірілді.',
                ),
              ),
            ),
            DeskHelpSupportAction(
              title: _t(
                ru: 'Скопировать brief для поддержки',
                en: 'Copy support brief',
                kk: 'Қолдау brief-ін көшіру',
              ),
              description: _t(
                ru: 'Шаблон уже содержит роль, email и очередь.',
                en: 'The template already includes role, email, and queue status.',
                kk: 'Шаблонда рөл, email және кезек күйі бар.',
              ),
              actionLabel: _t(ru: 'КОПИЯ', en: 'COPY', kk: 'КОПИЯ'),
              onTap: () => _copyToClipboard(
                _productionSupportBrief(
                  userEmail: user?.email ?? '',
                  acceptedCount: accepted.length,
                  inProductionCount: inProduction.length,
                  readyCount: ready.length,
                  currentOrder: current,
                ),
                _t(
                  ru: 'Brief для поддержки скопирован.',
                  en: 'Support brief copied.',
                  kk: 'Қолдау brief-і көшірілді.',
                ),
              ),
            ),
          ],
          footerText: _t(
            ru: 'Для быстрого ответа укажите этап и приложите скрин станции.',
            en: 'For a faster reply, mention the stage and attach a station screenshot.',
            kk: 'Жылдам жауап үшін кезеңді жазып, бекет скринын тіркеңіз.',
          ),
        ),
        primaryActionLabel: _t(
          ru: 'ПОЧЕМУ AVISHU',
          en: 'WHY AVISHU',
          kk: 'НЕГЕ AVISHU',
        ),
        onPrimaryAction: () => context.push('/why-avishu'),
        secondaryActionLabel: _t(
          ru: 'ВЫЙТИ ИЗ АККАУНТА',
          en: 'SIGN OUT',
          kk: 'АККАУНТТАН ШЫҒУ',
        ),
        onSecondaryAction: () async {
          await ref.read(authRepositoryProvider).signOut();
        },
      ),
    };
  }

  Widget _detailView(
    OrderModel order, {
    required Map<String, UserProfile> profiles,
  }) {
    final compact = ref.watch(appSettingsProvider).compactCards;

    return ProductionOrderDetailSection(
      order: order,
      clientDisplayName: _clientDisplayName(profiles, order),
      orderLabel:
          '${_t(ru: 'ЗАКАЗ', en: 'ORDER', kk: 'ТАПСЫРЫС')} #${order.shortId}',
      statusLabel: order.status.panelLabelFor(_language),
      statusSummary: order.status.roleDescriptionFor(_language),
      noteFieldLabel: _t(
        ru: 'Комментарий производства',
        en: 'Factory comment',
        kk: 'Өндіріс пікірі',
      ),
      technicalSheetTitle: _t(
        ru: 'ТЕХНИЧЕСКАЯ КАРТОЧКА',
        en: 'TECHNICAL SHEET',
        kk: 'ТЕХНИКАЛЫҚ КАРТОЧКА',
      ),
      clientNoteTitle: _t(
        ru: 'КОММЕНТАРИЙ КЛИЕНТА',
        en: 'CLIENT COMMENT',
        kk: 'КЛИЕНТ ПІКІРІ',
      ),
      franchiseeNoteTitle: _t(
        ru: 'ПОМЕТКА ФРАНЧАЙЗИ',
        en: 'FRANCHISE NOTE',
        kk: 'ФРАНЧАЙЗИ БЕЛГІСІ',
      ),
      noteRowLabel: _t(ru: 'Комментарий', en: 'Comment', kk: 'Пікір'),
      readyLabel: _t(
        ru: 'ГОТОВО. МОЖНО ПЕРЕДАВАТЬ ФРАНЧАЙЗИ.',
        en: 'READY. IT CAN BE HANDED TO THE FRANCHISEE.',
        kk: 'ДАЙЫН. ФРАНЧАЙЗИГЕ БЕРУГЕ БОЛАДЫ.',
      ),
      primaryActionLabel: _primaryActionLabel(order),
      onPrimaryAction: _primaryAction(order),
      compact: compact,
      isSubmitting: _isSubmitting,
      noteController: _noteController,
      summaryRows: OrderSummaryRows.forOrder(order, language: _language),
    );
  }

  List<ProductionTaskCardData> _taskCards(
    List<OrderModel> orders,
    Map<String, UserProfile> profiles,
    String footerLabel,
  ) {
    return orders
        .map(
          (order) => _taskCardData(
            order,
            clientDisplayName: _clientDisplayName(profiles, order),
            footerLabel: footerLabel,
          ),
        )
        .toList();
  }

  ProductionTaskCardData _taskCardData(
    OrderModel order, {
    required String clientDisplayName,
    required String footerLabel,
  }) {
    return ProductionTaskCardData(
      orderLabel:
          '${_t(ru: 'ЗАКАЗ', en: 'ORDER', kk: 'ТАПСЫРЫС')} #${order.shortId}',
      statusLabel: order.status.panelLabelFor(_language),
      productName: order.productName,
      facts: _taskFacts(order, clientDisplayName),
      footerLabel: footerLabel,
      onTap: () => _openOrder(order),
    );
  }

  List<String> _taskFacts(OrderModel order, String clientDisplayName) {
    return <String>[
      clientDisplayName,
      order.sizeLabel,
      _taskMetaLabel(order),
    ].where((item) => item.trim().isNotEmpty).toList();
  }

  String _taskMetaLabel(OrderModel order) {
    if (order.estimatedReadyAt != null) {
      return _t(
        ru: 'ГОТОВО К ${_shortDate(order.estimatedReadyAt!)}',
        en: 'READY BY ${_shortDate(order.estimatedReadyAt!)}',
        kk: '${_shortDate(order.estimatedReadyAt!)} ДАЙЫН',
      );
    }
    if (order.deliveryCity.trim().isNotEmpty) {
      return order.deliveryCity.trim();
    }
    return order.isPreorder
        ? _t(ru: 'ПРЕДЗАКАЗ', en: 'PREORDER', kk: 'АЛДЫН АЛА ТАПСЫРЫС')
        : _t(ru: 'В НАЛИЧИИ', en: 'IN STOCK', kk: 'ҚОЛДА БАР');
  }

  String _shortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  List<ProductionAnalyticsTileData> _analyticsTileData(
    ProductionAnalyticsSnapshot analytics,
  ) {
    return [
      ProductionAnalyticsTileData(
        label: _t(ru: 'ДО СТАРТА', en: 'START IN', kk: 'БАСТАУҒА ДЕЙІН'),
        value: _formatAnalyticsDuration(analytics.averageQueueToStartTime),
      ),
      ProductionAnalyticsTileData(
        label: _t(ru: 'ПОШИВ', en: 'TAILORING', kk: 'ТІГУ'),
        value: _formatAnalyticsDuration(analytics.averageTailoringTime),
      ),
      ProductionAnalyticsTileData(
        label: _t(ru: 'ДОСТАВКА', en: 'DELIVERY', kk: 'ЖЕТКІЗУ'),
        value: _formatAnalyticsDuration(analytics.averageCourierDeliveryTime),
      ),
      ProductionAnalyticsTileData(
        label: _t(ru: 'РИСК ЗАДЕРЖКИ', en: 'AT RISK', kk: 'КЕШІГУ ҚАУПІ'),
        value: '${analytics.overdueOrders}',
      ),
    ];
  }

  List<ProductionTailoringFact> _slowTailoringFacts(
    ProductionAnalyticsSnapshot analytics,
  ) {
    return analytics.productMetrics.take(3).map((metric) {
      return ProductionTailoringFact(
        productName: metric.productName,
        durationLabel: _formatAnalyticsDuration(metric.averageTailoringTime),
        orderCountLabel: _t(
          ru: '${metric.orderCount} заказа',
          en: '${metric.orderCount} orders',
          kk: '${metric.orderCount} тапсырыс',
        ),
      );
    }).toList();
  }

  String? _primaryActionLabel(OrderModel order) {
    return switch (order.status) {
      OrderStatus.accepted => _t(
        ru: 'ВЗЯТЬ В ПОШИВ',
        en: 'START PRODUCTION',
        kk: 'ТІГУДІ БАСТАУ',
      ),
      OrderStatus.inProduction => _t(
        ru: 'ЗАВЕРШИТЬ ПОШИВ',
        en: 'FINISH PRODUCTION',
        kk: 'ТІГУДІ АЯҚТАУ',
      ),
      _ => null,
    };
  }

  VoidCallback? _primaryAction(OrderModel order) {
    return switch (order.status) {
      OrderStatus.accepted => () {
        _startProduction(order);
      },
      OrderStatus.inProduction => () {
        _finishProduction(order);
      },
      _ => null,
    };
  }

  Future<void> _startProduction(OrderModel order) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final currentUserId = ref.read(currentUserProvider).value?.uid ?? '';
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _finishProduction(OrderModel order) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final currentUserId = ref.read(currentUserProvider).value?.uid ?? '';
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

  String _productionSupportBrief({
    required String userEmail,
    required int acceptedCount,
    required int inProductionCount,
    required int readyCount,
    required OrderModel? currentOrder,
  }) {
    final accountEmail = userEmail.trim().isEmpty
        ? 'not_provided'
        : userEmail.trim();
    final currentOrderLabel = currentOrder == null
        ? 'not_attached'
        : '#${currentOrder.shortId}';

    return [
      'AVISHU SUPPORT BRIEF',
      'ROLE: PRODUCTION',
      'ACCOUNT: $accountEmail',
      'TO START: $acceptedCount',
      'IN WORK: $inProductionCount',
      'READY: $readyCount',
      'CURRENT TASK: $currentOrderLabel',
      'ISSUE:',
      '- What is blocked',
      '- Which stage is affected',
      '- Screenshot attached: yes / no',
    ].join('\n');
  }

  void _openOrder(OrderModel order) {
    _noteController.text = order.productionNote;
    setState(() => _selectedOrder = order);
  }
}
