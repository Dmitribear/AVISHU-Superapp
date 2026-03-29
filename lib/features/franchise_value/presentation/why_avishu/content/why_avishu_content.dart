import '../../../../../shared/i18n/app_localization.dart';

class WhyAvishuValueBlock {
  final String title;
  final String description;

  const WhyAvishuValueBlock({required this.title, required this.description});
}

class WhyAvishuContent {
  final String heroTitle;
  final String heroStatement;
  final String heroSummary;
  final List<WhyAvishuValueBlock> valueBlocks;
  final List<String> flowLabels;
  final String closingTitle;
  final String closingStatement;

  const WhyAvishuContent({
    required this.heroTitle,
    required this.heroStatement,
    required this.heroSummary,
    required this.valueBlocks,
    required this.flowLabels,
    required this.closingTitle,
    required this.closingStatement,
  });
}

WhyAvishuContent whyAvishuContentFor(AppLanguage language) {
  if (language == AppLanguage.russian) {
    return const WhyAvishuContent(
      heroTitle: 'WHY AVISHU',
      heroStatement: 'ОПЕРАЦИОННАЯ СИСТЕМА ДЛЯ СОВРЕМЕННОЙ FASHION-ФРАНШИЗЫ',
      heroSummary:
          'ОДНА СИСТЕМА СОЕДИНЯЕТ КЛИЕНТСКИЙ СПРОС, ФРАНЧАЙЗ-ОПЕРАЦИИ И ИСПОЛНЕНИЕ В ЦЕХЕ В РЕАЛЬНОМ ВРЕМЕНИ.',
      valueBlocks: [
        WhyAvishuValueBlock(
          title: 'ПОЛНЫЙ КОНТРОЛЬ',
          description:
              'КЛИЕНТ, ФРАНЧАЙЗИ И ПРОИЗВОДСТВО ВИДНЫ В ОДНОМ ОПЕРАЦИОННОМ ПОТОКЕ.',
        ),
        WhyAvishuValueBlock(
          title: 'СИСТЕМА REALTIME',
          description:
              'ЗАКАЗЫ ДВИГАЮТСЯ МЕЖДУ РОЛЯМИ МГНОВЕННО, БЕЗ РУЧНЫХ ПЕРЕДАЧ.',
        ),
        WhyAvishuValueBlock(
          title: 'СИНХРОНИЗАЦИЯ ЦЕХА',
          description:
              'ПРОИЗВОДСТВО ПОЛУЧАЕТ И ОБНОВЛЯЕТ ЗАДАЧИ БЕЗ ОПЕРАЦИОННЫХ ЗАДЕРЖЕК.',
        ),
        WhyAvishuValueBlock(
          title: 'ПРЕМИАЛЬНЫЙ ОПЫТ',
          description:
              'КЛИЕНТСКИЙ ИНТЕРФЕЙС ПОДДЕРЖИВАЕТ ЛЮКСОВОЕ ПОЗИЦИОНИРОВАНИЕ БРЕНДА.',
        ),
        WhyAvishuValueBlock(
          title: 'МАСШТАБИРУЕМАЯ МОДЕЛЬ',
          description:
              'ОДНА СИСТЕМА ПОДДЕРЖИВАЕТ НЕСКОЛЬКО ФРАНЧАЙЗ-ТОЧЕК И КОМАНД.',
        ),
      ],
      flowLabels: ['КЛИЕНТ', 'ФРАНЧАЙЗИ', 'ПРОИЗВОДСТВО', 'КЛИЕНТ'],
      closingTitle: 'БИЗНЕС У ВАС В КАРМАНЕ',
      closingStatement: 'ОДНА СИСТЕМА. ТРИ РОЛИ. ПОЛНАЯ ВИДИМОСТЬ.',
    );
  }

  return const WhyAvishuContent(
    heroTitle: 'WHY AVISHU',
    heroStatement: 'THE OPERATING SYSTEM FOR MODERN FASHION FRANCHISE',
    heroSummary:
        'ONE SYSTEM CONNECTS CLIENT DEMAND, FRANCHISE OPERATIONS, AND FACTORY EXECUTION IN REAL TIME.',
    valueBlocks: [
      WhyAvishuValueBlock(
        title: 'FULL CONTROL',
        description: 'TRACK CLIENT, FRANCHISE, AND PRODUCTION IN ONE FLOW.',
      ),
      WhyAvishuValueBlock(
        title: 'REALTIME SYSTEM',
        description:
            'ORDERS MOVE INSTANTLY BETWEEN ROLES WITHOUT MANUAL HANDOFFS.',
      ),
      WhyAvishuValueBlock(
        title: 'PRODUCTION SYNC',
        description:
            'FACTORY RECEIVES AND UPDATES TASKS WITHOUT OPERATIONAL DELAYS.',
      ),
      WhyAvishuValueBlock(
        title: 'PREMIUM EXPERIENCE',
        description: 'CLIENT-FACING UX REFLECTS LUXURY BRAND POSITIONING.',
      ),
      WhyAvishuValueBlock(
        title: 'SCALABLE MODEL',
        description: 'ONE SYSTEM SUPPORTS MULTIPLE FRANCHISE POINTS AND TEAMS.',
      ),
    ],
    flowLabels: ['CLIENT', 'FRANCHISEE', 'FACTORY', 'CLIENT'],
    closingTitle: 'BUSINESS IN YOUR POCKET',
    closingStatement: 'ONE SYSTEM. THREE ROLES. TOTAL VISIBILITY.',
  );
}
