# AVISHU

Внутренний Flutter-проект, объединяющий клиентскую витрину и операционный контур бренда **AVISHU**. Приложение предоставляет единое рабочее пространство для клиентов (каталог, оформление и трекинг заказа), франчайзи и производства.

> **Важно:** Этот документ предназначен для команды разработки. Здесь описано устройство кодовой базы, архитектурные решения, распределение ответственности между сервисами и вектор дальнейшего рефакторинга.

---

## 🛠 Технологический стек

* **Фреймворк:** Flutter, Dart 3.9
* **State Management & DI:** Riverpod
* **Routing:** GoRouter
* **Backend:** Firebase (Core, Auth, Cloud Firestore)
* **Геосервисы:** `flutter_map` + OpenStreetMap, `geocoding`
* **UI/Design:** Google Fonts, кастомная Brutalist-тема

---

## 🚀 Быстрый старт

1. Установить Flutter SDK и проверить окружение через `flutter doctor`.
2. Подтянуть зависимости:

```bash
flutter pub get
```

3. Убедиться, что в проекте актуален `lib/firebase_options.dart` и подключён нужный Firebase-проект.
4. Запустить приложение:

```bash
flutter run
```

Полезные команды для повседневной работы:

```bash
flutter analyze
flutter test
dart format lib test
```

## Точка входа

`lib/main.dart`


## Проект организован по принципу Feature-first.

Верхний уровень
`lib/core/` — Глобальная логика: роутер (app_router.dart), тема (app_theme.dart), типографика и палитра.

`lib/shared/` — Переиспользуемые ресурсы: общие виджеты, провайдеры состояния (auth, settings), локализация и утилиты Firestore.

`lib/features/` — Изолированные бизнес-фичи.

### Устройство фичи (features/)
Каждая фича (orders, auth, products и т.д.) делится на слои:

`data/` — Репозитории (Firebase/API).

`domain`/ — Модели, перечисления и бизнес-сервисы (логика расчетов).

`presentation/` — UI-слой (экраны и локальные виджеты).
## Как устроен проект

Проект организован по feature-first схеме. Верхний уровень небольшой:

```text
lib/
  core/
  features/
  shared/
```

### `core/`

Базовый слой, который не привязан к конкретной фиче.

- `core/router/app_router.dart`
  Здесь живёт `GoRouter`. Он решает, куда отправить пользователя после логина и какой кабинет показать для каждой роли.

- `core/theme/colors.dart`
  Палитра проекта.

- `core/theme/typography.dart`
  Общая типографика и преднастроенные текстовые стили.

- `core/theme/app_theme.dart`
  Главная тема приложения. Настраивает `ThemeData`, кнопки, поля ввода, карточки, диалоги и общую brutalist-подачу.

### `features/`

Бизнес-логика разбита по предметным областям. Внутри каждой фичи, где это оправдано, используются подпапки `data`, `domain`, `presentation`.

#### `features/auth/`

- `data/auth_repository.dart`
  Работа с Firebase Auth и записью базового профиля в Firestore.

  Главные методы:
  - `signIn()` — вход по email и паролю
  - `register()` — регистрация и первичная запись пользователя в коллекцию `users`
  - `signOut()` — выход
  - `fetchUserData()` — чтение роли и имени из Firestore

- `domain/app_user.dart`
  Лёгкая доменная модель текущего пользователя.

- `domain/user_role.dart`
  Роли системы: клиент, франчайзи, производство, админ.

- `presentation/login_screen.dart`
  Экран входа.

- `presentation/register_screen.dart`
  Экран регистрации.

#### `features/orders/`

Самая насыщенная зона проекта. Здесь лежат заказ, статусы, аналитика, карта, shared UI для заказа и большие экраны.

- `data/order_repository.dart`
  Главный репозиторий заказов. Работает с коллекцией `orders`, подколлекциями `items` и `history`, а также подтягивает товары и лояльность во время создания заказа.

  Ключевые методы:
  - `createOrder()` — создаёт заказ, его item-строки, историю и вычисляет цены с учётом лояльности
  - `updateOrderStatus()` — универсальный перевод статуса
  - `acceptOrder()` — принятие франчайзи
  - `startProduction()` — старт пошива
  - `completeOrder()` — перевод в `ready`
  - `finalizeOrder()` — завершение заказа
  - `cancelOrder()` — отмена
  - `updateCourierLocation()` — обновление координат курьера
  - `ordersByStatus()` / `ordersByStatuses()` — потоки заказов по статусам
  - `allOrders()` — поток всех заказов
  - `clientOrders()` — поток заказов клиента
  - `franchiseeOrders()` — поток заказов франчайзи
  - `productionQueue()` — очередь производства
  - `getOrderById()` — разовое чтение одного заказа

- `domain/enums/`
  Справочники по статусам, доставке, приоритету, оплате и типу исполнения.

- `domain/models/`
  Доменные модели заказа:
  - `OrderModel`
  - `OrderItemModel`
  - `OrderHistoryEntry`
  - `OrderTimelineEntry`

- `domain/services/order_status_transition_service.dart`
  Жёстко описывает допустимые переходы между статусами.

  Главные методы:
  - `canTransition()` — проверка перехода
  - `validateTransition()` — проверка с ошибкой при недопустимом переходе

- `domain/services/order_map_location_resolver.dart`
  Внутренний предсказуемый resolver для маршрута, когда адрес не удалось геокодировать через системный сервис.

  Что делает:
  - выбирает центр города
  - определяет origin для доставки или pickup
  - вычисляет fallback destination
  - умеет интерполировать движение по маршруту

- `domain/services/order_geocoding_service.dart`
  Обёртка над `locationFromAddress`.

  Что делает:
  - пытается геокодировать введённый адрес
  - пробует несколько форматов запроса
  - если lookup не удался, возвращает fallback из `OrderMapLocationResolver`

  Главный метод:
  - `resolveRoute()`

- `domain/services/order_analytics_service.dart`
  Собирает сводные метрики по заказам.

  Главные методы:
  - `buildFranchiseeSnapshot()` — показатели для франчайзи
  - `buildProductionSnapshot()` — показатели для производства

- `presentation/client/client_dashboard.dart`
  Крупный клиентский экран. Сейчас здесь собраны каталог, карточка товара, checkout, ввод адреса, карта превью, трекинг и часть вспомогательных UI-блоков.

  Важное замечание:
  файл рабочий, но большой. Следующий безопасный шаг для рефакторинга — вынос каталога, checkout и блока трекинга в отдельные presentation-срезы.

- `presentation/franchisee/franchisee_dashboard.dart`
  Рабочий экран франчайзи.

- `presentation/production/production_dashboard.dart`
  Рабочий экран производства.

- `presentation/shared/order_digital_twin_helpers.dart`
  Вспомогательные pure-функции для цифрового двойника заказа.

  Что здесь полезно:
  - `formatOrderStatus()`
  - `formatOrderPriority()`
  - `formatFulfillmentTypeLabel()`
  - `formatOrderEta()`
  - `formatOrderMetaDate()`
  - `getOrderCurrentStageDuration()`
  - `getOrderCurrentStageStartedAt()`
  - `getResponsibleLabel()`
  - `getClientDisplayLabel()`
  - `mapOrderHistoryToTimeline()`

- `presentation/shared/order_digital_twin_card.dart`
  Визуальный блок цифрового двойника заказа.

- `presentation/shared/order_formatters.dart`
  Форматирование денежных значений, дат и сопутствующих строк для заказа.

- `presentation/shared/order_panels.dart`
  Shared-панели для карточек и summary-блоков.

#### `features/products/`

- `data/product_repository.dart`
  Репозиторий товаров.

  Главные методы:
  - `watchActiveProducts()` — поток активных товаров
  - `fetchActiveProducts()` — разовая загрузка активных товаров
  - `fetchById()` — один товар по id
  - `upsertProduct()` — запись или обновление товара

- `domain/models/product_model.dart`
  Модель товара, его цены, статуса и характеристик.

- `domain/enums/product_status.dart`
  Справочник статусов товара.

#### `features/users/`

- `data/user_profile_repository.dart`
  Репозиторий профилей пользователей.

  Главные методы:
  - `fetchById()`
  - `watchById()`
  - `watchAll()`
  - `upsertProfile()`

- `domain/models/user_profile.dart`
  Полная модель профиля из Firestore.

- `domain/services/loyalty_program.dart`
  Отдельный расчётный модуль программы лояльности.

  Главные методы:
  - `benefitsForTotalSpent()` — определяет текущий tier
  - `profileSnapshot()` — возвращает прогресс до следующего tier
  - `pricing()` — считает скидку, бонусы и итоговую цену на checkout
  - `applyPurchase()` — обновляет spend и бонусный баланс после покупки

#### `features/franchise_value/`

- `presentation/why_avishu_screen.dart`
- `presentation/why_avishu_content.dart`
- `presentation/why_avishu_metrics.dart`

Отдельный информационный блок про ценность бренда.

### `shared/`

Общий слой проекта. Здесь лежат то, что переиспользуется между фичами.

- `shared/providers/global_state.dart`
  Глобальные Riverpod-провайдеры, связанные с авторизацией и текущим пользователем.

  Главные провайдеры:
  - `authStateChangesProvider`
  - `currentUserProvider`

- `shared/providers/app_settings.dart`
  Локальные настройки приложения.

  Что хранит:
  - язык
  - compact mode карточек
  - размер карточки каталога
  - переключатели уведомлений и production sound

  Методы контроллера:
  - `setNotifications()`
  - `setProductionSound()`
  - `setCompactCards()`
  - `setLanguage()`
  - `setCatalogCardSize()`

- `shared/i18n/app_localization.dart`
  Базовые функции локализации и enum языка.

- `shared/utils/firestore_parsing.dart`
  Приведение Firestore-значений к Dart-типам.

- `shared/widgets/`
  Общие виджеты интерфейса:
  - `avishu_button.dart`
  - `avishu_shell.dart`
  - `avishu_mobile_frame.dart`
  - `app_settings_sheet.dart`
  - `role_switch_sheet.dart`
  - `avishu_order_tracker.dart`
  - и декоративные элементы

- `shared/demo/demo_seed_service.dart`
  Сервис наполнения demo-данными.

  Главный сценарий:
  - `seedAll()` создаёт пользователей, товары и набор заказов в разных статусах

## Роутинг

Роутинг живёт в `lib/core/router/app_router.dart`.

Маршруты:

- `/login`
- `/register`
- `/loading`
- `/client`
- `/franchisee`
- `/production`
- `/why-avishu`

Как работает redirect:

- если auth ещё грузится, открывается `/loading`
- если пользователя нет, любой приватный маршрут отправит на `/login`
- если пользователь есть, стартовый маршрут перекинет его в экран его роли

#### 📦 Orders (Заказы) — Ядро системы

Центральный модуль, отвечающий за жизненный цикл продукта.

* **`OrderRepository`**: CRUD операции, работа с подколлекциями `items` и `history`. Содержит стримы заказов для разных ролей (`clientOrders`, `productionQueue` и др.).
* **`OrderStatusTransitionService`**: Валидация переходов (например, нельзя перевести заказ из `new` сразу в `ready`, минуя `accepted`).
* **Геопозиционирование**:
  * **`OrderGeocodingService`**: Попытка прямого геокодинга адреса.
  * **`OrderMapLocationResolver`**: Fallback-механизм. Если адрес не найден, выбирает центр города и интерполирует маршрут.
* **`OrderAnalyticsService`**: Формирование метрик для дашбордов франчайзи и цеха.

#### 🔐 Auth (Авторизация)

* Работа через **`AuthRepository`** (Firebase Auth). При регистрации автоматически создается профиль в коллекции `users`.
* **Ролевая модель**: `client`, `franchisee`, `production`, `admin`.

#### 👤 Users & Loyalty (Профили и Лояльность)

* **`LoyaltyProgram`**: Чистый расчетный модуль. Считает Tier пользователя по общему обороту (`spend`), вычисляет скидки и бонусы на этапе checkout.

#### 🛍 Products (Товары)

* Управление активным каталогом через **`ProductRepository`**. Модели поддерживают вариативность характеристик и статусы наличия.

## Atomic UI: что уже переведено

Проект пока не целиком на atomic architecture. Полностью обещать это было бы нечестно.
Но общий вектор задан, и один рабочий срез уже вынесен по атомарной схеме.

### Delivery map card

Папка:

```text
lib/features/orders/presentation/shared/delivery_map_card/
  atoms/
    delivery_courier_marker.dart
    delivery_map_attribution.dart
    delivery_map_progress_bar.dart
    delivery_map_tag.dart
  molecules/
    delivery_map_marker_chip.dart
    delivery_map_metric_row.dart
  organisms/
    order_delivery_map_card.dart
  delivery_map_palette.dart
```

Что здесь за что отвечает:

- atoms
  Самые маленькие визуальные кирпичики. Они ничего не знают о сценарии заказа целиком.

- molecules
  Комбинации из нескольких atoms с одной маленькой задачей. Например строка метрики или chip маркера.

- organisms
  Готовый самостоятельный блок экрана. В нашем случае это целая карточка карты доставки.

- `order_delivery_map_card.dart`
  Сохранён как совместимый barrel-файл, чтобы старые импорты не ломались при рефакторинге.

Правило для дальнейшего выноса простое:

- если блок устойчиво переиспользуется и имеет ясную границу ответственности, выносим его
- если блок ещё сильно живёт внутри одного сценария и постоянно меняется, держим его рядом с экраном

### Client dashboard sections

Следующий вынесенный срез живёт здесь:

```text
lib/features/orders/presentation/client/dashboard_sections/
  atoms/
    client_section_heading.dart
    client_surface_card.dart
  molecules/
    client_delivery_method_card.dart
  organisms/
    client_checkout_address_section.dart
    client_checkout_loyalty_section.dart
    client_checkout_method_section.dart
    client_checkout_summary_section.dart
    client_checkout_total_section.dart
    client_payment_form_section.dart
    client_payment_section.dart
    client_tracking_details_section.dart
    client_tracking_actions_row.dart
    client_tracking_empty_state_card.dart
    client_tracking_note_card.dart
    client_tracking_status_section.dart
```

Это не “общий UI на все случаи”, а набор секций именно для `ClientDashboard`.

Что туда вынесено:

- адресный блок checkout
- блок лояльности checkout
- выбор способа получения
- статусная карточка трекинга
- карточки заметок по заказу
- нижний ряд действий на экране трекинга

Что сознательно осталось в `client_dashboard.dart`:

- state экрана
- `TextEditingController`
- вызовы Riverpod-провайдеров
- расчёты pricing и loyalty
- навигационные переходы между `root / product / checkout / payment / tracking`

Это сделано специально: секции уже вынесены, но orchestration экрана пока остаётся в одном месте и по-прежнему читается сверху вниз.

### Why Avishu presentation

После рефакторинга экран ценности франшизы живёт в отдельном срезе:

```text
lib/features/franchise_value/presentation/why_avishu/
  atoms/
    why_avishu_metric_box.dart
    why_avishu_surface_card.dart
  molecules/
    why_avishu_flow_step_row.dart
    why_avishu_value_card.dart
  organisms/
    why_avishu_closing_section.dart
    why_avishu_flow_section.dart
    why_avishu_hero_section.dart
    why_avishu_live_summary_section.dart
    why_avishu_value_blocks_section.dart
  content/
    why_avishu_content.dart
  models/
    why_avishu_metrics.dart
  screen/
    why_avishu_body.dart
    why_avishu_screen.dart
  why_avishu.dart
```

Старые файлы `presentation/why_avishu_screen.dart`, `presentation/why_avishu_content.dart` и `presentation/why_avishu_metrics.dart` оставлены как совместимые barrel-файлы, чтобы роутер, тесты и существующие импорты не ломались.

## Договорённости по коду

Это важнее любой схемы папок.

### Именование

- называем поля и методы по смыслу, а не по длине
- избегаем аббревиатур, если они не общеизвестны
- булевы флаги называем как состояние: `isLive`, `isPickup`, `isCompleted`
- публичный API виджетов должен читаться без догадок

### Комментарии

- не пишем комментарии ради количества
- не дублируем код словами
- комментарий нужен только там, где есть нетривиальное бизнес-правило, внешний контракт или важное ограничение

### UI-слой

- shared UI раскладываем по atomic-папкам только там, где это реально упрощает сопровождение
- не плодим абстракции заранее
- если новый блок используется один раз и ещё не устоялся, сначала держим его рядом с экраном

### Data и domain

- Firestore и внешние интеграции держим в `data`
- расчёты, правила и enum-логика держим в `domain`
- presentation не должен сам считать бизнес-логику, если её можно вынести в pure helper или service

## Тесты

Папка `test/` покрывает ключевые расчётные и shared-модули:

- `order_geocoding_service_test.dart`
- `order_map_location_resolver_test.dart`
- `order_status_transition_service_test.dart`
- `order_analytics_service_test.dart`
- `order_digital_twin_helpers_test.dart`
- `loyalty_program_test.dart`
- `app_settings_test.dart`
- `catalog_product_adapter_test.dart`
- `avishu_order_tracker_test.dart`
- `why_avishu_metrics_test.dart`
- `order_model_test.dart`

Если меняется логика расчётов, статусов, адресов, лояльности или таймлайна заказа, тесты для этих модулей нужно обновлять в том же PR.

## Что стоит вынести следующим шагом

Самые понятные кандидаты на следующий рефактор:

1. checkout-секцию из `client_dashboard.dart`
2. трекинг заказа из `client_dashboard.dart`
3. каталог и карточку товара из `client_dashboard.dart`
4. общие summary-блоки для production и franchisee dashboards

Смысл именно такой последовательности:

- сначала режем большие сценарии по экранным блокам
- потом уже смотрим, где действительно нужны новые atoms и molecules

## Коротко о текущем состоянии

Сейчас проект рабочий, но он ещё в переходной фазе.
Есть крепкое feature-first основание, нормальные domain/data сервисы и уже начатый аккуратный переход к более собранному presentation-слою.
Если продолжать рефакторинг без спешки и выносить только устоявшиеся блоки, кодовая база будет упрощаться без потери темпа.
