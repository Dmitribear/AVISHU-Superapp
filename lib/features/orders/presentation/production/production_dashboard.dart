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
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_role.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/services/order_analytics_service.dart';
import '../../../users/data/user_profile_repository.dart';
import '../../../users/domain/models/user_profile.dart';
import '../shared/desk_help/desk_help.dart';
import '../shared/order_digital_twin_card.dart';
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
              'production-${_tab.index}-${_selectedOrder?.id ?? 'none'}',
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

    return switch (_tab) {
      ProductionTab.dashboard => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(
            title: _t(
              ru: 'ОЧЕРЕДЬ ЗАДАЧ',
              en: 'TASK QUEUE',
              kk: 'ТАПСЫРМАЛАР КЕЗЕГІ',
            ),
            subtitle: _t(
              ru: 'После подтверждения заказ попадает в очередь цеха и проходит этапы пошива до готовности.',
              en: 'After acceptance, the order enters the factory queue and moves through production until ready.',
              kk: 'Қабылданғаннан кейін тапсырыс цех кезегіне түседі және дайын болғанға дейін тігу кезеңдерінен өтеді.',
            ),
            accent: _t(
              ru: 'АКТИВНЫХ ЗАДАЧ: ${accepted.length + inProduction.length}',
              en: 'ACTIVE TASKS: ${accepted.length + inProduction.length}',
              kk: 'БЕЛСЕНДІ ТАПСЫРМАЛАР: ${accepted.length + inProduction.length}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  _t(ru: 'К пошиву', en: 'To Tailor', kk: 'Тігінге'),
                  '${accepted.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'В работе', en: 'In Progress', kk: 'Жұмыста'),
                  '${inProduction.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  _t(ru: 'Готово', en: 'Ready', kk: 'Дайын'),
                  '${ready.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _factoryAnalyticsCard(analytics),
          if (current != null) ...[
            const SizedBox(height: 12),
            _taskCard(
              current,
              clientDisplayName: _clientDisplayName(profiles, current),
            ),
          ],
          if (analytics.productMetrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _slowProductsCard(analytics),
          ],
        ],
      ),
      ProductionTab.queue => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(_t(ru: 'К ПОШИВУ', en: 'TO TAILOR', kk: 'ТІГІНГЕ')),
          const SizedBox(height: 12),
          if (accepted.isEmpty)
            _emptyCard(
              _t(
                ru: 'Новых задач в очереди пока нет.',
                en: 'No new tasks in queue yet.',
                kk: 'Кезекте әзірге жаңа тапсырмалар жоқ.',
              ),
            ),
          ...accepted.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _sectionLabel(_t(ru: 'В РАБОТЕ', en: 'IN PROGRESS', kk: 'ЖҰМЫСТА')),
          const SizedBox(height: 12),
          if (inProduction.isEmpty)
            _emptyCard(
              _t(
                ru: 'После запуска пошива заказ перейдет в этот раздел.',
                en: 'Once production starts, the order will appear in this section.',
                kk: 'Тігу басталғаннан кейін тапсырыс осы бөлімге ауысады.',
              ),
            ),
          ...inProduction.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
            ),
          ),
        ],
      ),
      ProductionTab.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(
            _t(ru: 'ЗАВЕРШЕННЫЕ', en: 'COMPLETED READY', kk: 'АЯҚТАЛҒАНДАР'),
          ),
          const SizedBox(height: 12),
          if (ready.isEmpty)
            _emptyCard(
              _t(
                ru: 'Завершенные заказы пока отсутствуют.',
                en: 'No completed ready orders yet.',
                kk: 'Аяқталған тапсырыстар әзірге жоқ.',
              ),
            ),
          ...ready.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _taskCard(
                order,
                clientDisplayName: _clientDisplayName(profiles, order),
              ),
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
                  _t(ru: 'РАБОЧЕЕ МЕСТО', en: 'WORKSTATION', kk: 'ЖҰМЫС ОРНЫ'),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    ru: 'Интерфейс мастера',
                    en: 'Operator Interface',
                    kk: 'Шебер интерфейсі',
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
                    kk: 'Экран ағымдағы тапсырманы, тапсырыс мәртебесін және келесі қолжетімді әрекетті көрсетеді.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DeskHelpGuideSection(
            compact: compact,
            eyebrow: _t(
              ru: 'КАК РАБОТАТЬ НА СТАНЦИИ',
              en: 'HOW TO WORK AT THE STATION',
              kk: 'БЕКЕТТЕ ҚАЛАЙ ЖҰМЫС ІСТЕУ КЕРЕК',
            ),
            title: _t(
              ru: 'Рабочий ритм держится на понятных шагах.',
              en: 'The workstation stays fast when every step is clear.',
              kk: 'Әр қадам анық болса, жұмыс ырғағы жоғалмайды.',
            ),
            description: _t(
              ru: 'Станция помогает быстро взять задачу, видеть статус и отмечать готовность без лишних переходов.',
              en: 'The station helps you pick up a task quickly, see its status, and mark it ready without extra navigation.',
              kk: 'Бекет тапсырманы тез алуға, мәртебені көруге және дайындықты артық өтусіз белгілеуге көмектеседі.',
            ),
            points: [
              DeskHelpGuidePoint(
                title: _t(
                  ru: 'Начинайте с ближайшей задачи',
                  en: 'Start with the nearest task',
                  kk: 'Ең жақын тапсырмадан бастаңыз',
                ),
                description: _t(
                  ru: 'Очередь показывает, какие заказы ждут запуска и что уже находится в работе.',
                  en: 'The queue shows which orders are waiting to start and which ones are already in progress.',
                  kk: 'Кезек қай тапсырыстар іске қосуды күтіп тұрғанын және қайсысы жұмыста екенін көрсетеді.',
                ),
              ),
              DeskHelpGuidePoint(
                title: _t(
                  ru: 'Обновляйте этапы сразу по факту',
                  en: 'Update stages as soon as they happen',
                  kk: 'Кезеңдерді бірден жаңартып отырыңыз',
                ),
                description: _t(
                  ru: 'Так франчайзи и клиент видят реальный статус, а очередь не расползается по срокам.',
                  en: 'This keeps franchisee and client status accurate and prevents the queue from drifting out of sync.',
                  kk: 'Осылай франчайзи мен клиент нақты мәртебені көреді және кезек мерзімнен ауытқымайды.',
                ),
              ),
              DeskHelpGuidePoint(
                title: _t(
                  ru: 'Отмечайте готовность без паузы',
                  en: 'Mark ready without delay',
                  kk: 'Дайындықты кідіріссіз белгілеңіз',
                ),
                description: _t(
                  ru: 'Когда вещь собрана, сразу переводите ее в готово, чтобы выдача не задерживалась.',
                  en: 'Once the garment is complete, move it to ready immediately so handoff is not delayed.',
                  kk: 'Бұйым дайын болған сәтте оны бірден ready мәртебесіне өткізіңіз, сонда беру кешікпейді.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DeskHelpSystemFlowSection(
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
                  ru: 'Клиент создает заказ и передает в систему все данные по изделию, размеру и доставке.',
                  en: 'The client creates the order and sends the system the garment, size, and delivery details.',
                  kk: 'Клиент тапсырыс жасап, жүйеге бұйым, өлшем және жеткізу бойынша барлық деректі береді.',
                ),
              ),
              DeskHelpFlowStep(
                title: localizedRoleLabel(UserRole.franchisee, _language),
                details: _t(
                  ru: 'Франчайзи принимает заказ, подтверждает его и отправляет в работу с сохранением всех заметок.',
                  en: 'The franchisee accepts the order, confirms it, and sends it into work while keeping all notes attached.',
                  kk: 'Франчайзи тапсырысты қабылдап, растап, барлық ескертпелерді сақтай отырып жұмысқа жібереді.',
                ),
              ),
              DeskHelpFlowStep(
                title: localizedRoleLabel(UserRole.production, _language),
                details: _t(
                  ru: 'Производство берет задачу в цех, обновляет этапы и отвечает за перевод заказа в готово.',
                  en: 'Production takes the task into the workshop, updates the stages, and moves the order into ready.',
                  kk: 'Өндіріс тапсырманы цехқа алып, кезеңдерді жаңартады және тапсырысты дайын мәртебесіне өткізеді.',
                ),
              ),
              DeskHelpFlowStep(
                title: localizedRoleLabel(UserRole.client, _language),
                details: _t(
                  ru: 'Клиент получает обновление в трекинге и завершает путь получением готового заказа.',
                  en: 'The client receives the update in tracking and completes the journey by receiving the finished order.',
                  kk: 'Клиент бақылауда жаңартуды алып, дайын тапсырысты алу арқылы процесті аяқтайды.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DeskHelpSupportSection(
            compact: compact,
            eyebrow: _t(
              ru: 'ПОМОЩЬ И ПОДДЕРЖКА',
              en: 'HELP & SUPPORT',
              kk: 'КӨМЕК ЖӘНЕ ҚОЛДАУ',
            ),
            title: _t(
              ru: 'Подготовьте эскалацию без лишней переписки.',
              en: 'Prepare an escalation without extra back-and-forth.',
              kk: 'Эскалацияны артық хат алмасусыз дайындаңыз.',
            ),
            description: _t(
              ru: 'Если задача заблокирована, можно быстро скопировать нужные данные и передать их в поддержку.',
              en: 'If a task is blocked, you can quickly copy the right details and pass them to support.',
              kk: 'Егер тапсырма тоқтап қалса, қажетті деректі тез көшіріп, оны қолдауға беруге болады.',
            ),
            actions: [
              DeskHelpSupportAction(
                title: _t(
                  ru: 'Скопировать email аккаунта',
                  en: 'Copy account email',
                  kk: 'Аккаунт email-ын көшіру',
                ),
                description: _t(
                  ru: 'Нужно, если поддержке требуется быстро найти рабочую учетную запись.',
                  en: 'Useful when support needs to identify your working account quickly.',
                  kk: 'Қолдау қызметіне жұмыс аккаунтыңызды тез табу керек болса қажет.',
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
                  ru: 'Так поддержка сразу увидит, какой заказ сейчас требует внимания.',
                  en: 'This lets support see which order currently needs attention.',
                  kk: 'Осылай қолдау қай тапсырысқа дәл қазір назар керек екенін бірден көреді.',
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
                  ru: 'Скопировать бриф для поддержки',
                  en: 'Copy support brief',
                  kk: 'Қолдау мәтінін көшіру',
                ),
                description: _t(
                  ru: 'Шаблон включает роль, email и текущее состояние очереди.',
                  en: 'The template includes your role, email, and the current queue status.',
                  kk: 'Шаблонда рөліңіз, email және кезектің ағымдағы күйі бар.',
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
                    ru: 'Бриф для поддержки скопирован.',
                    en: 'Support brief copied.',
                    kk: 'Қолдау мәтіні көшірілді.',
                  ),
                ),
              ),
            ],
            footerText: _t(
              ru: 'Для быстрого ответа укажите, на каком этапе задача остановилась и приложите скрин экрана станции.',
              en: 'To get help faster, mention at which stage the task stopped and attach a screenshot of the station screen.',
              kk: 'Жауапты тезірек алу үшін тапсырма қай кезеңде тоқтағанын жазып, бекет экранының скринін тіркеңіз.',
            ),
          ),
          const SizedBox(height: 12),
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
      ),
    };
  }

  Widget _detailView(
    OrderModel order, {
    required Map<String, UserProfile> profiles,
  }) {
    final isAccepted = order.status == OrderStatus.accepted;
    final isInProduction = order.status == OrderStatus.inProduction;

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
            ru: 'ТЕХНИЧЕСКАЯ КАРТОЧКА',
            en: 'TECHNICAL SHEET',
            kk: 'ТЕХНИКАЛЫҚ КАРТОЧКА',
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
        if (order.franchiseeNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: _t(
              ru: 'ПОМЕТКА ФРАНЧАЙЗИ',
              en: 'FRANCHISE NOTE',
              kk: 'ФРАНЧАЙЗИ БЕЛГІСІ',
            ),
            rows: [
              OrderInfoRowData(
                label: _t(ru: 'Комментарий', en: 'Comment', kk: 'Пікір'),
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
                kk: 'Өндіріс пікірі',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isAccepted)
          AvishuButton(
            text: _t(
              ru: 'ВЗЯТЬ В ПОШИВ',
              en: 'START PRODUCTION',
              kk: 'ТІГУДІ БАСТАУ',
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
            text: _t(
              ru: 'ЗАВЕРШИТЬ ПОШИВ',
              en: 'FINISH PRODUCTION',
              kk: 'ТІГУДІ АЯҚТАУ',
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
                    kk: 'ДАЙЫН. ФРАНЧАЙЗИДІҢ БЕРУІН КҮТУДЕ.',
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

  Widget _factoryAnalyticsCard(ProductionAnalyticsSnapshot analytics) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              ru: 'КАК ИДЁТ ЦЕХ',
              en: 'FACTORY SNAPSHOT',
              kk: 'ЦЕХ ҚАЛАЙ ЖҰМЫС ІСТЕП ЖАТЫР',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              ru: 'Показываем только то, что реально помогает держать ритм: когда стартуем, сколько шьём и где есть риск задержки.',
              en: 'Only the metrics that help keep the rhythm: when work starts, how long tailoring takes, and where delays may appear.',
              kk: 'Ритмді ұстап тұруға көмектесетін ғана метрикалар: қашан бастаймыз, тігу қанша уақыт алады және қай жерде кешігу қаупі бар.',
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
                      _t(ru: 'До старта', en: 'Start in', kk: 'Бастау уақыты'),
                      _formatAnalyticsDuration(
                        analytics.averageQueueToStartTime,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(ru: 'Пошив', en: 'Tailoring', kk: 'Тігу уақыты'),
                      _formatAnalyticsDuration(analytics.averageTailoringTime),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(ru: 'Доставка', en: 'Delivery', kk: 'Жеткізу'),
                      _formatAnalyticsDuration(
                        analytics.averageCourierDeliveryTime,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _analyticsMetricCell(
                      _t(
                        ru: 'Риск задержки',
                        en: 'At risk',
                        kk: 'Кешігу қаупі',
                      ),
                      '${analytics.overdueOrders}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            _t(
              ru: 'Сегодня готово ${analytics.readyToday} заказов.',
              en: '${analytics.readyToday} orders became ready today.',
              kk: 'Бүгін ${analytics.readyToday} тапсырыс дайын болды.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _slowProductsCard(ProductionAnalyticsSnapshot analytics) {
    final visibleMetrics = analytics.productMetrics.take(3).toList();
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              ru: 'ЧТО ШЬЁТСЯ ДОЛЬШЕ',
              en: 'WHAT TAKES LONGER',
              kk: 'НЕ ҰЗАҒЫРАҚ ТІГІЛЕДІ',
            ),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 10),
          ...visibleMetrics.map(
            (metric) => Padding(
              padding: EdgeInsets.only(
                bottom: metric == visibleMetrics.last ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      metric.productName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatAnalyticsDuration(metric.averageTailoringTime),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          ru: '${metric.orderCount} заказа',
                          en: '${metric.orderCount} orders',
                          kk: '${metric.orderCount} тапсырыс',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsMetricCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _taskCard(OrderModel order, {required String clientDisplayName}) {
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
          Text(order.sizeLabel, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: order.status.progressValue),
          const SizedBox(height: 10),
          Text(
            _t(ru: 'ОТКРЫТЬ', en: 'OPEN', kk: 'АШУ'),
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
      'TO TAILOR: $acceptedCount',
      'IN PROGRESS: $inProductionCount',
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
