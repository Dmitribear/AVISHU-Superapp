const { Telegraf, Scenes, session, Markup } = require('telegraf');
const { db, admin } = require('./firebase-config');
const dotenv = require('dotenv');

dotenv.config();

const bot = new Telegraf(process.env.BOT_TOKEN);

// --- Scenes for Product Creation ---
const createProductScene = new Scenes.WizardScene(
  'CREATE_PRODUCT_SCENE',
  async (ctx) => {
    await ctx.reply('Введите название товара:', Markup.keyboard([['❌ Отмена создания']]).resize());
    ctx.wizard.state.productData = {};
    return ctx.wizard.next();
  },
  async (ctx) => {
    if (ctx.message.text === '❌ Отмена создания' || ctx.message.text === '🔄 Сменить роль') {
      await ctx.reply('Создание товара отменено.', getMenuKeyboard(ctx.session.profile?.role));
      return ctx.scene.leave();
    }
    ctx.wizard.state.productData.name = ctx.message.text;
    await ctx.reply('Введите описание товара:');
    return ctx.wizard.next();
  },
  async (ctx) => {
    if (ctx.message.text === '❌ Отмена создания' || ctx.message.text === '🔄 Сменить роль') {
      await ctx.reply('Создание товара отменено.', getMenuKeyboard(ctx.session.profile?.role));
      return ctx.scene.leave();
    }
    ctx.wizard.state.productData.description = ctx.message.text;
    await ctx.reply('Введите цену (в KZT):');
    return ctx.wizard.next();
  },
  async (ctx) => {
    if (ctx.message.text === '❌ Отмена создания' || ctx.message.text === '🔄 Сменить роль') {
      await ctx.reply('Создание товара отменено.', getMenuKeyboard(ctx.session.profile?.role));
      return ctx.scene.leave();
    }
    const price = parseFloat(ctx.message.text);
    if (isNaN(price)) {
      await ctx.reply('Пожалуйста, введите числовое значение для цены.');
      return;
    }
    ctx.wizard.state.productData.price = price;
    await ctx.reply('Введите категорию (например, Одежда, Аксессуары):');
    return ctx.wizard.next();
  },
  async (ctx) => {
    if (ctx.message.text === '❌ Отмена создания' || ctx.message.text === '🔄 Сменить роль') {
      await ctx.reply('Создание товара отменено.', getMenuKeyboard(ctx.session.profile?.role));
      return ctx.scene.leave();
    }
    ctx.wizard.state.productData.category = ctx.message.text;
    
    const data = ctx.wizard.state.productData;
    const summary = `Название: ${data.name}\nОписание: ${data.description}\nЦена: ${data.price} KZT\nКатегория: ${data.category}`;
    
    await ctx.reply(`Проверьте данные:\n\n${summary}`, Markup.inlineKeyboard([
      Markup.button.callback('✅ Подтвердить', 'confirm_product'),
      Markup.button.callback('❌ Отмена', 'cancel_product')
    ]));
    return ctx.wizard.next();
  },
  async (ctx) => {
    return ctx.scene.leave();
  }
);

const stage = new Scenes.Stage([createProductScene]);
bot.use(session());
bot.use(stage.middleware());

// --- Helper: Check User Role ---
async function getUserProfile(phone) {
  const snapshot = await db.collection('users').where('phone', '==', phone).limit(1).get();
  if (snapshot.empty) return null;
  return snapshot.docs[0].data();
}

function getMenuKeyboard(role) {
  if (role === 'franchisee') {
    return Markup.keyboard([
      ['📦 Создать товар'],
      ['🔄 Сменить роль']
    ]).resize();
  } else if (role === 'factory_worker') {
    return Markup.keyboard([
      ['📋 Доступные заказы'],
      ['🛠 Заказы в работе'],
      ['🔄 Сменить роль']
    ]).resize();
  }
  return Markup.removeKeyboard();
}
// --- Bot Commands ---
bot.start(async (ctx) => {
  await ctx.reply('Добро пожаловать в AVISHU бот! Выберите вашу роль для тестирования:', 
    Markup.inlineKeyboard([
      [Markup.button.callback('👔 Франчайзи', 'set_role_franchisee')],
      [Markup.button.callback('🧵 Швея', 'set_role_seamstress')]
    ])
  );
});

bot.action('set_role_franchisee', async (ctx) => {
  const role = 'franchisee';
  ctx.session.profile = { 
    role: role, 
    fullName: ctx.from.first_name || 'Тест Франчайзи' 
  };

  // Subscribe user (optional for franchisee, but good to have)
  try {
    await db.collection('bot_subscriptions').doc(ctx.from.id.toString()).set({
      telegramId: ctx.from.id,
      role: role,
      updatedAt: admin.firestore.Timestamp.now()
    }, { merge: true });
  } catch (e) {
    console.error('Subscription error:', e);
  }

  await ctx.answerCbQuery();
  await ctx.reply('✅ Вы вошли как Франчайзи.', 
    Markup.keyboard([
      ['📦 Создать товар'],
      ['🔄 Сменить роль']
    ]).resize()
  );
});

bot.action('set_role_seamstress', async (ctx) => {
  const role = 'factory_worker';
  ctx.session.profile = { 
    role: role, 
    fullName: ctx.from.first_name || 'Тест Швея' 
  };

  // Subscribe user for notifications
  try {
    await db.collection('bot_subscriptions').doc(ctx.from.id.toString()).set({
      telegramId: ctx.from.id,
      role: role,
      updatedAt: admin.firestore.Timestamp.now()
    }, { merge: true });
  } catch (e) {
    console.error('Subscription error:', e);
  }

  await ctx.answerCbQuery();
  await ctx.reply('✅ Вы вошли как Швея. Теперь вы будете получать уведомления о новых заказах.', 
    Markup.keyboard([
      ['📋 Доступные заказы'],
      ['🛠 Заказы в работе'],
      ['🔄 Сменить роль']
    ]).resize()
  );
});

bot.hears('📦 Создать товар', async (ctx) => {
  if (ctx.session.profile?.role !== 'franchisee') return;
  await ctx.scene.enter('CREATE_PRODUCT_SCENE');
});

bot.hears('📋 Доступные заказы', async (ctx) => {
  if (ctx.session.profile?.role !== 'factory_worker') return;
  
  // Firestore doesn't support case-insensitive queries, so we check both 'accepted' and 'Accepted'
  const snapshot = await db.collection('orders').where('status', 'in', ['accepted', 'Accepted']).get();
  if (snapshot.empty) {
    return ctx.reply('Нет доступных заказов для пошива.');
  }

  let message = 'Доступные заказы:\n\n';
  const buttons = [];

  snapshot.docs.forEach(doc => {
    const order = doc.data();
    message += `📦 Заказ #${order.orderNumber || doc.id.substring(0,6)}\nТовар: ${order.productName}\nЦена: ${order.totalAmount} ${order.currency}\n---\n`;
    buttons.push([Markup.button.callback(`Взять #${order.orderNumber || doc.id.substring(0,6)}`, `take_order_${doc.id}`)]);
  });

  await ctx.reply(message, Markup.inlineKeyboard(buttons));
});

bot.hears('🛠 Заказы в работе', async (ctx) => {
  if (ctx.session.profile?.role !== 'factory_worker') return;

  const snapshot = await db.collection('orders').where('status', 'in', ['in_production', 'InProduction']).get();
  if (snapshot.empty) {
    return ctx.reply('У вас нет активных заказов в работе.');
  }

  let message = 'Ваши заказы в работе:\n\n';
  const buttons = [];

  snapshot.docs.forEach(doc => {
    const order = doc.data();
    message += `🧵 Заказ #${order.orderNumber || doc.id.substring(0,6)}\nТовар: ${order.productName}\nСтатус: ${order.status}\n---\n`;
    buttons.push([Markup.button.callback(`✅ Завершить пошив #${order.orderNumber || doc.id.substring(0,6)}`, `complete_order_${doc.id}`)]);
  });

  await ctx.reply(message, Markup.inlineKeyboard(buttons));
});

bot.action(/complete_order_(.+)/, async (ctx) => {
  const orderId = ctx.match[1];
  const now = admin.firestore.Timestamp.now();

  try {
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();
    
    if (!orderDoc.exists) {
      await ctx.answerCbQuery('Заказ не найден.');
      return;
    }

    const orderData = orderDoc.data();
    const currentStatus = (orderData.status || '').toLowerCase();
    
    if (currentStatus !== 'in_production') {
      await ctx.answerCbQuery('Заказ не в пошиве.');
      return ctx.reply(`Ошибка: Статус заказа "${orderData.status}", а должен быть "in_production".`);
    }

    await orderRef.update({
      status: 'ready',
      updatedAt: now,
      lastStatusChangedAt: now,
      completedAt: now, // Matches OrderRepository.completeOrder
      productionNote: `${orderData.productionNote || ''}\nПошив завершен швеей (TG: @${ctx.from.username || ctx.from.id})`
    });

    // Add to history
    const historyId = orderRef.collection('history').doc().id;
    await orderRef.collection('history').doc(historyId).set({
      id: historyId,
      orderId: orderId,
      fromStatus: orderData.status,
      toStatus: 'ready',
      changedByUserId: `tg_${ctx.from.id}`,
      changedByRole: 'factory_worker',
      comment: 'Пошив завершен через Telegram бота',
      createdAt: now
    });

    await ctx.answerCbQuery('Вы завершили пошив!');
    await ctx.reply(`🎉 Пошив заказа #${orderData.orderNumber || orderId.substring(0,6)} завершен! Статус изменен на "ready".`);
  } catch (e) {
    console.error(e);
    await ctx.answerCbQuery('Ошибка.');
    await ctx.reply('Произошла ошибка при завершении заказа.');
  }
});

bot.hears('🔄 Сменить роль', async (ctx) => {
  await ctx.reply('Выберите вашу роль:', 
    Markup.inlineKeyboard([
      [Markup.button.callback('👔 Франчайзи', 'set_role_franchisee')],
      [Markup.button.callback('🧵 Швея', 'set_role_seamstress')]
    ])
  );
});


bot.action('confirm_product', async (ctx) => {
  const data = ctx.scene.state.wizard.state.productData;
  const productId = db.collection('products').doc().id;
  const now = admin.firestore.Timestamp.now();

  const productModel = {
    id: productId,
    name: data.name,
    slug: productId,
    description: data.description,
    shortDescription: data.description.substring(0, 50),
    category: data.category,
    material: '',
    silhouette: '',
    atelierNote: '',
    sections: [],
    colors: [],
    sizes: [],
    defaultColor: '',
    defaultSize: '',
    specifications: [],
    care: [],
    price: data.price,
    currency: 'KZT',
    coverImage: '',
    gallery: [],
    isPreorderAvailable: false,
    defaultProductionDays: 3,
    status: 'active',
    createdAt: now,
    updatedAt: now
  };

  try {
    await db.collection('products').doc(productId).set(productModel);
    await ctx.answerCbQuery('Товар успешно создан!');
    await ctx.editMessageText(`✅ Товар "${data.name}" успешно создан в базе!`);
    await ctx.reply('Главное меню:', getMenuKeyboard(ctx.session.profile?.role));
  } catch (e) {
    console.error(e);
    await ctx.answerCbQuery('Ошибка при создании.');
    await ctx.reply('Произошла ошибка при сохранении товара.', getMenuKeyboard(ctx.session.profile?.role));
  }
  return ctx.scene.leave();
});

bot.action('cancel_product', async (ctx) => {
  await ctx.answerCbQuery('Отменено');
  await ctx.editMessageText('Создание товара отменено.');
  await ctx.reply('Главное меню:', getMenuKeyboard(ctx.session.profile?.role));
  return ctx.scene.leave();
});


bot.action(/take_order_(.+)/, async (ctx) => {
  const orderId = ctx.match[1];
  const now = admin.firestore.Timestamp.now();

  try {
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();
    
    if (!orderDoc.exists) {
      await ctx.answerCbQuery('Заказ не найден.');
      return;
    }

    const orderData = orderDoc.data();
    const currentStatus = (orderData.status || '').toLowerCase();
    
    if (currentStatus !== 'accepted') {
      await ctx.answerCbQuery('Заказ уже в работе или не готов.');
      return ctx.reply(`Ошибка: Статус заказа "${orderData.status}", а должен быть "accepted".`);
    }

    await orderRef.update({
      status: 'in_production',
      updatedAt: now,
      lastStatusChangedAt: now,
      productionNote: `Взят в работу швеей (TG: @${ctx.from.username || ctx.from.id})`
    });

    // Also add to history if we want to be consistent with the Flutter app
    const historyId = orderRef.collection('history').doc().id;
    await orderRef.collection('history').doc(historyId).set({
      id: historyId,
      orderId: orderId,
      fromStatus: orderData.status,
      toStatus: 'in_production',
      changedByUserId: `tg_${ctx.from.id}`,
      changedByRole: 'factory_worker',
      comment: 'Взят через Telegram бота',
      createdAt: now
    });

    await ctx.answerCbQuery('Вы взяли заказ в работу!');
    await ctx.reply(`✅ Вы взяли заказ #${orderDoc.data().orderNumber || orderId.substring(0,6)} в работу.`);
  } catch (e) {
    console.error(e);
    await ctx.answerCbQuery('Ошибка.');
    await ctx.reply('Произошла ошибка при обновлении статуса заказа.');
  }
});

bot.launch().then(() => {
  console.log('Bot is running...');
});

// --- Real-time Notifications ---
const startTime = admin.firestore.Timestamp.now();

db.collection('orders')
  .where('status', 'in', ['accepted', 'Accepted'])
  .onSnapshot(async (snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
      // Check if it's a new 'accepted' order (either just added or status changed to accepted)
      const order = change.doc.data();
      const status = (order.status || '').toLowerCase();
      
      if (status !== 'accepted') return;

      // Only notify about orders that became 'accepted' AFTER the bot started
      // We check updatedAt to capture status changes
      const updatedAt = order.updatedAt ? order.updatedAt.toMillis() : 0;
      if (updatedAt < startTime.toMillis()) return;

      const message = `🔔 Новый заказ готов к пошиву!\n\n📦 Заказ #${order.orderNumber || change.doc.id.substring(0,6)}\nТовар: ${order.productName}\nЦена: ${order.totalAmount} ${order.currency}`;
      
      const inlineKeyboard = Markup.inlineKeyboard([
        [Markup.button.callback('🧵 Взять в пошив', `take_order_${change.doc.id}`)]
      ]);

      // Get all subscribed seamstresses
      const subsSnapshot = await db.collection('bot_subscriptions').where('role', '==', 'factory_worker').get();
      subsSnapshot.forEach(async (subDoc) => {
        const sub = subDoc.data();
        try {
          await bot.telegram.sendMessage(sub.telegramId, message, inlineKeyboard);
        } catch (e) {
          console.error(`Failed to send notification to ${sub.telegramId}:`, e);
        }
      });
    });
  }, (error) => {
    console.error('Firestore listener error:', error);
  });

// Enable graceful stop
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
