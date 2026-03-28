import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/orders/data/order_repository.dart';
import '../../features/orders/domain/enums/delivery_method.dart';
import '../../features/orders/domain/services/order_map_location_resolver.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/domain/enums/product_status.dart';
import '../../features/products/domain/models/product_model.dart';
import '../../features/users/data/user_profile_repository.dart';

class DemoSeedService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final UserProfileRepository _userProfiles;
  final ProductRepository _products;
  final OrderRepository _orders;

  DemoSeedService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance,
      _userProfiles = UserProfileRepository(firestore: firestore),
      _products = ProductRepository(firestore: firestore),
      _orders = OrderRepository(firestore: firestore);

  Future<DemoSeedResult> seedAll() async {
    final users = await _seedUsers();
    final products = _demoProducts();
    for (final product in products) {
      await _products.upsertProduct(product);
    }

    await _clearDemoOrders(users.client.userId);

    final newOrderId = await _orders.createOrder(
      clientId: users.client.userId,
      productId: products[0].id,
      productName: products[0].name,
      sizeLabel: 'M',
      quantity: 1,
      unitPrice: products[0].price,
      imageUrl: products[0].coverImage,
      amount: products[0].price + DeliveryMethod.courier.fee,
      isPreorder: false,
      deliveryMethod: DeliveryMethod.courier,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Dostyk Ave 25',
      apartment: '12',
      paymentLast4: '4242',
      clientNote: 'Demo new order',
    );

    final inProductionOrderId = await _orders.createOrder(
      clientId: users.client.userId,
      productId: products[1].id,
      productName: products[1].name,
      sizeLabel: 'L',
      quantity: 1,
      unitPrice: products[1].price,
      imageUrl: products[1].coverImage,
      amount: products[1].price + DeliveryMethod.courier.fee,
      isPreorder: true,
      deliveryMethod: DeliveryMethod.courier,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Abylai Khan Ave 90',
      apartment: '7',
      paymentLast4: '4242',
      clientNote: 'Urgent preorder demo',
    );
    await _orders.acceptOrder(
      inProductionOrderId,
      note: 'Accepted by demo franchisee',
      changedByUserId: users.franchisee.userId,
      franchiseeId: users.franchisee.userId,
    );
    await _orders.startProduction(
      inProductionOrderId,
      note: 'Moved to factory queue',
      changedByUserId: users.factoryWorker.userId,
    );

    final readyOrderId = await _orders.createOrder(
      clientId: users.client.userId,
      productId: products[2].id,
      productName: products[2].name,
      sizeLabel: 'S',
      quantity: 1,
      unitPrice: products[2].price,
      imageUrl: products[2].coverImage,
      amount: products[2].price + DeliveryMethod.pickup.fee,
      isPreorder: false,
      deliveryMethod: DeliveryMethod.pickup,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Esentai Mall',
      apartment: '',
      paymentLast4: '1111',
      clientNote: 'Ready order demo',
    );
    await _orders.acceptOrder(
      readyOrderId,
      note: 'Accepted by demo franchisee',
      changedByUserId: users.franchisee.userId,
      franchiseeId: users.franchisee.userId,
    );
    await _orders.startProduction(
      readyOrderId,
      note: 'Factory started tailoring',
      changedByUserId: users.factoryWorker.userId,
    );

    final liveCourierOrderId = await _orders.createOrder(
      clientId: users.client.userId,
      productId: products[3].id,
      productName: products[3].name,
      sizeLabel: 'M',
      quantity: 1,
      unitPrice: products[3].price,
      imageUrl: products[3].coverImage,
      amount: products[3].price + DeliveryMethod.courier.fee,
      isPreorder: false,
      deliveryMethod: DeliveryMethod.courier,
      deliveryCity: 'Almaty',
      deliveryAddress: 'Mega Alma-Ata',
      apartment: '1',
      paymentLast4: '3535',
      clientNote: 'Live courier map demo',
    );
    await _orders.acceptOrder(
      liveCourierOrderId,
      note: 'Accepted by demo franchisee',
      changedByUserId: users.franchisee.userId,
      franchiseeId: users.franchisee.userId,
    );
    await _orders.startProduction(
      liveCourierOrderId,
      note: 'Factory started tailoring',
      changedByUserId: users.factoryWorker.userId,
    );
    await _orders.completeOrder(
      liveCourierOrderId,
      note: 'Order is packed and handed to courier',
      changedByUserId: users.factoryWorker.userId,
    );
    final liveCourierRoute = OrderMapLocationResolver.resolveRoute(
      deliveryMethod: DeliveryMethod.courier,
      city: 'Almaty',
      address: 'Mega Alma-Ata',
      apartment: '1',
    );
    await _orders.updateCourierLocation(
      liveCourierOrderId,
      courierLocation: OrderMapLocationResolver.interpolate(
        liveCourierRoute.originLocation,
        liveCourierRoute.destinationLocation,
        0.38,
      ),
      note: 'Courier left the atelier',
    );
    await _orders.completeOrder(
      readyOrderId,
      note: 'Factory finished the order',
      changedByUserId: users.factoryWorker.userId,
    );

    await _auth.signOut();

    return DemoSeedResult(
      users: <SeededUserAccount>[
        users.client,
        users.franchisee,
        users.factoryWorker,
        users.admin,
      ],
      productIds: products.map((product) => product.id).toList(),
      orderIds: <String>[
        newOrderId,
        inProductionOrderId,
        readyOrderId,
        liveCourierOrderId,
      ],
    );
  }

  Future<_SeededUsers> _seedUsers() async {
    final client = await _ensureUser(
      _DemoUserConfig(
        email: 'client@avishu.demo',
        password: 'Avishu123!',
        fullName: 'Amina Client',
        phone: '+77010000001',
        city: 'Almaty',
        loyaltyPoints: 240,
        role: UserRole.client,
      ),
    );
    final franchisee = await _ensureUser(
      _DemoUserConfig(
        email: 'franchisee@avishu.demo',
        password: 'Avishu123!',
        fullName: 'Dana Franchisee',
        phone: '+77010000002',
        city: 'Almaty',
        loyaltyPoints: 0,
        role: UserRole.franchisee,
      ),
    );
    final factoryWorker = await _ensureUser(
      _DemoUserConfig(
        email: 'factory@avishu.demo',
        password: 'Avishu123!',
        fullName: 'Maksat Factory',
        phone: '+77010000003',
        city: 'Almaty',
        loyaltyPoints: 0,
        role: UserRole.production,
      ),
    );
    final admin = await _ensureUser(
      _DemoUserConfig(
        email: 'admin@avishu.demo',
        password: 'Avishu123!',
        fullName: 'Admin AVISHU',
        phone: '+77010000004',
        city: 'Almaty',
        loyaltyPoints: 0,
        role: UserRole.admin,
      ),
    );

    return _SeededUsers(
      client: client,
      franchisee: franchisee,
      factoryWorker: factoryWorker,
      admin: admin,
    );
  }

  Future<SeededUserAccount> _ensureUser(_DemoUserConfig config) async {
    UserCredential? credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: config.email,
        password: config.password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' ||
          error.code == 'invalid-credential') {
        credential = await _auth.createUserWithEmailAndPassword(
          email: config.email,
          password: config.password,
        );
      } else {
        rethrow;
      }
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Could not create or sign in demo user ${config.email}');
    }

    await _userProfiles.upsertProfile(
      userId: user.uid,
      role: config.role,
      fullName: config.fullName,
      email: config.email,
      phone: config.phone,
      city: config.city,
      loyaltyPoints: config.loyaltyPoints,
    );

    await _auth.signOut();

    return SeededUserAccount(
      userId: user.uid,
      email: config.email,
      password: config.password,
      role: config.role,
    );
  }

  Future<void> _clearDemoOrders(String clientId) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('clientId', isEqualTo: clientId)
        .get();

    for (final doc in snapshot.docs) {
      final items = await doc.reference.collection('items').get();
      for (final item in items.docs) {
        await item.reference.delete();
      }

      final history = await doc.reference.collection('history').get();
      for (final entry in history.docs) {
        await entry.reference.delete();
      }

      await doc.reference.delete();
    }
  }

  List<ProductModel> _demoProducts() {
    final now = DateTime.now();
    return <ProductModel>[
      ProductModel(
        id: 'she-skirt',
        name: 'Skirt SHE',
        slug: 'skirt-she',
        description:
            'Юбка-миди в брутальном минимализме AVISHU. Крой A-line, высокая посадка, '
            'эко-кожа с матовым финишем. Создана для тех, кто выбирает форму и функцию.',
        shortDescription: 'Юбка-миди из эко-кожи, A-line, высокая посадка.',
        category: 'skirts',
        material: 'Эко-кожа / подкладка — вискоза',
        silhouette: 'A-line midi',
        atelierNote:
            'Индивидуальный пошив 3-4 рабочих дня. Размерная сетка — AVISHU standard.',
        sections: const <String>['Новинки', 'Юбки'],
        colors: const <String>['Кофе', 'Черный', 'Экрю'],
        sizes: const <String>['XS', 'S', 'M', 'L'],
        defaultColor: 'Кофе',
        defaultSize: 'S',
        specifications: const <ProductSpecEntry>[
          ProductSpecEntry(label: 'Силуэт', value: 'A-line midi'),
          ProductSpecEntry(label: 'Посадка', value: 'Высокая талия'),
          ProductSpecEntry(label: 'Длина', value: '72 см (разм. M)'),
          ProductSpecEntry(label: 'Артикул', value: 'SKIRT-SHE'),
          ProductSpecEntry(label: 'Состав', value: 'Эко-кожа 100%'),
        ],
        care: const <String>[
          'Деликатная сухая чистка.',
          'Не стирать в машине.',
          'Хранить на мягкой вешалке или в чехле.',
          'Избегать прямых солнечных лучей.',
        ],
        price: 30500,
        currency: 'KZT',
        coverImage:
            'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
        gallery: const <String>[
          'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: true,
        defaultProductionDays: 4,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'line-suit',
        name: 'Suit LINE',
        slug: 'suit-line',
        description:
            'Расслабленный костюм premium-класса с мягкой structured структурой. '
            'Жакет оверсайз + прямые брюки. Пошив вручную в ателье AVISHU.',
        shortDescription: 'Костюм оверсайз, structured fit, ручной пошив.',
        category: 'suits',
        material: 'Шерсть / полиэстер — тонкая подкладка',
        silhouette: 'Oversized structured',
        atelierNote:
            'Комплект: жакет + брюки. Пошив по предзаказу 5 рабочих дней.',
        sections: const <String>['Костюмы', 'Новинки'],
        colors: const <String>['Черный', 'Молочный'],
        sizes: const <String>['XS', 'S', 'M', 'L', 'XL'],
        defaultColor: 'Черный',
        defaultSize: 'S',
        specifications: const <ProductSpecEntry>[
          ProductSpecEntry(label: 'Силуэт', value: 'Oversized structured'),
          ProductSpecEntry(label: 'Длина жакета', value: '72 см (разм. M)'),
          ProductSpecEntry(label: 'Длина брюк', value: '100 см (разм. M)'),
          ProductSpecEntry(label: 'Артикул', value: 'SUIT-LINE'),
          ProductSpecEntry(label: 'Состав', value: 'Шерсть 60% / ПЭ 40%'),
        ],
        care: const <String>[
          'Только сухая чистка.',
          'Не стирать в машине.',
          'Гладить через ткань при низкой температуре.',
          'Хранить в чехле в вертикальном положении.',
        ],
        price: 68200,
        currency: 'KZT',
        coverImage:
            'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
        gallery: const <String>[
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: true,
        defaultProductionDays: 5,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'lune-cardigan',
        name: 'Cardigan LUNE',
        slug: 'cardigan-lune',
        description:
            'Мягкий кардиган из хлопко-кашемировой смеси для сезонного layering. '
            'Прямой крой, удлинённый силуэт, базовая модель капсулы AVISHU.',
        shortDescription:
            'Кардиган прямого кроя, хлопок-кашемир, базовая капсула.',
        category: 'cardigans',
        material: 'Хлопок 70% / кашемир 30%',
        silhouette: 'Straight relaxed',
        atelierNote: 'В наличии. Отправка на следующий день.',
        sections: const <String>['Кардиганы', 'Базовые'],
        colors: const <String>['Экрю', 'Серый', 'Пыльный розовый'],
        sizes: const <String>['XS', 'S', 'M', 'L'],
        defaultColor: 'Экрю',
        defaultSize: 'S',
        specifications: const <ProductSpecEntry>[
          ProductSpecEntry(label: 'Силуэт', value: 'Straight relaxed'),
          ProductSpecEntry(label: 'Длина', value: '82 см (разм. M)'),
          ProductSpecEntry(label: 'Артикул', value: 'CDG-LUNE'),
          ProductSpecEntry(label: 'Состав', value: 'Хлопок 70% / кашемир 30%'),
        ],
        care: const <String>[
          'Ручная стирка при 30°C.',
          'Сушить в горизонтальном положении.',
          'Не выжимать.',
          'Хранить сложенным, не на вешалке.',
        ],
        price: 26800,
        currency: 'KZT',
        coverImage:
            'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
        gallery: const <String>[
          'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: false,
        defaultProductionDays: 0,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'arc-trousers',
        name: 'Trousers ARC',
        slug: 'trousers-arc',
        description:
            'Брюки wide-leg с высокой посадкой premium-качества. Драпируются естественно, '
            'создавая архитектурный объём снизу. Базовая позиция AVISHU.',
        shortDescription:
            'Брюки wide-leg, высокая посадка, архитектурный объём.',
        category: 'trousers',
        material: 'Вискоза / лён — лёгкая смесь',
        silhouette: 'Wide-leg high-rise',
        atelierNote:
            'В наличии. Можно заказать по индивидуальным меркам — +3 дня.',
        sections: const <String>['Брюки', 'Базовые'],
        colors: const <String>['Черный', 'Бежевый', 'Хаки'],
        sizes: const <String>['XS', 'S', 'M', 'L'],
        defaultColor: 'Черный',
        defaultSize: 'S',
        specifications: const <ProductSpecEntry>[
          ProductSpecEntry(label: 'Силуэт', value: 'Wide-leg high-rise'),
          ProductSpecEntry(label: 'Посадка', value: 'Высокая'),
          ProductSpecEntry(label: 'Длина', value: '100 см (разм. M)'),
          ProductSpecEntry(label: 'Артикул', value: 'TRS-ARC'),
          ProductSpecEntry(label: 'Состав', value: 'Вискоза 60% / Лён 40%'),
        ],
        care: const <String>[
          'Деликатная стирка до 30°C.',
          'Гладить при низкой температуре.',
          'Хранить на вешалке со зажимами.',
        ],
        price: 24200,
        currency: 'KZT',
        coverImage:
            'https://images.unsplash.com/photo-1495385794356-15371f348c31?auto=format&fit=crop&w=1200&q=80',
        gallery: const <String>[
          'https://images.unsplash.com/photo-1495385794356-15371f348c31?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: false,
        defaultProductionDays: 0,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      ProductModel(
        id: 'mono-coat',
        name: 'Coat MONO',
        slug: 'coat-mono',
        description:
            'Пальто-макси longline из шерсти для зимней капсулы AVISHU. '
            'Прямой крой, минималистичные детали, идеальный лаконичный силуэт.',
        shortDescription: 'Пальто-макси longline, шерсть, зимняя капсула.',
        category: 'outerwear',
        material: 'Шерсть 80% / полиамид 20%',
        silhouette: 'Longline straight',
        atelierNote:
            'Пошив по предзаказу 6 рабочих дней. Доступна подгонка по фигуре.',
        sections: const <String>['Новинки', 'Верхняя одежда'],
        colors: const <String>['Черный', 'Серый меланж', 'Кемел'],
        sizes: const <String>['S', 'M', 'L', 'XL'],
        defaultColor: 'Черный',
        defaultSize: 'M',
        specifications: const <ProductSpecEntry>[
          ProductSpecEntry(label: 'Силуэт', value: 'Longline straight'),
          ProductSpecEntry(label: 'Длина', value: '118 см (разм. M)'),
          ProductSpecEntry(label: 'Артикул', value: 'CT-MONO'),
          ProductSpecEntry(label: 'Состав', value: 'Шерсть 80% / ПА 20%'),
          ProductSpecEntry(label: 'Застёжка', value: 'Скрытые кнопки'),
        ],
        care: const <String>[
          'Только сухая чистка.',
          'Хранить в чехле в вертикальном положении.',
          'Не стирать в воде.',
          'Подшивать у специалиста.',
        ],
        price: 89500,
        currency: 'KZT',
        coverImage:
            'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=1200&q=80',
        gallery: const <String>[
          'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
        ],
        isPreorderAvailable: true,
        defaultProductionDays: 6,
        status: ProductStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class DemoSeedResult {
  final List<SeededUserAccount> users;
  final List<String> productIds;
  final List<String> orderIds;

  const DemoSeedResult({
    required this.users,
    required this.productIds,
    required this.orderIds,
  });
}

class SeededUserAccount {
  final String userId;
  final String email;
  final String password;
  final UserRole role;

  const SeededUserAccount({
    required this.userId,
    required this.email,
    required this.password,
    required this.role,
  });
}

class _DemoUserConfig {
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final String city;
  final int loyaltyPoints;
  final UserRole role;

  const _DemoUserConfig({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.loyaltyPoints,
    required this.role,
  });
}

class _SeededUsers {
  final SeededUserAccount client;
  final SeededUserAccount franchisee;
  final SeededUserAccount factoryWorker;
  final SeededUserAccount admin;

  const _SeededUsers({
    required this.client,
    required this.franchisee,
    required this.factoryWorker,
    required this.admin,
  });
}
