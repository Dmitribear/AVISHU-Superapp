import '../../features/auth/domain/user_role.dart';

enum AppLanguage { russian, english, kazakh }

enum CatalogCardSize { compact, standard, large }

String tr(
  AppLanguage language, {
  required String ru,
  required String en,
  String? kk,
}) {
  if (language == AppLanguage.kazakh) {
    return kk ?? en; // Fallback to English if Kazakh is missing
  }
  return language == AppLanguage.russian ? ru : en;
}

String appLanguageLabel(AppLanguage language) {
  switch (language) {
    case AppLanguage.russian:
      return 'RU';
    case AppLanguage.english:
      return 'EN';
    case AppLanguage.kazakh:
      return 'KZ';
  }
}

String catalogCardSizeLabel(CatalogCardSize size) {
  switch (size) {
    case CatalogCardSize.compact:
      return 'S';
    case CatalogCardSize.standard:
      return 'M';
    case CatalogCardSize.large:
      return 'L';
  }
}

String localizedRoleLabel(UserRole role, AppLanguage language) {
  switch (role) {
    case UserRole.client:
      return tr(language, ru: 'КЛИЕНТ', en: 'CLIENT', kk: 'КЛИЕНТ');
    case UserRole.franchisee:
      return tr(language, ru: 'ФРАНЧАЙЗИ', en: 'FRANCHISEE', kk: 'ФРАНЧАЙЗИ');
    case UserRole.production:
      return tr(language, ru: 'ПРОИЗВОДСТВО', en: 'FACTORY', kk: 'ӨНДІРІС');
    case UserRole.admin:
      return 'ADMIN';
  }
}

String localizeCatalogSection(AppLanguage language, String value) {
  const mapping = <String, Map<AppLanguage, String>>{
    'Новинки': {
      AppLanguage.russian: 'Новинки',
      AppLanguage.english: 'New In',
      AppLanguage.kazakh: 'Жаңадан келгендер',
    },
    'Верхняя одежда': {
      AppLanguage.russian: 'Верхняя одежда',
      AppLanguage.english: 'Outerwear',
      AppLanguage.kazakh: 'Сыртқы киім',
    },
    'Кардиганы и кофты': {
      AppLanguage.russian: 'Кардиганы и кофты',
      AppLanguage.english: 'Cardigans & Tops',
      AppLanguage.kazakh: 'Кардигандар мен жейделер',
    },
    'Костюмы': {
      AppLanguage.russian: 'Костюмы',
      AppLanguage.english: 'Suits',
      AppLanguage.kazakh: 'Костюмдер',
    },
    'База': {
      AppLanguage.russian: 'База',
      AppLanguage.english: 'Essentials',
      AppLanguage.kazakh: 'Негізгі',
    },
    'Брюки': {
      AppLanguage.russian: 'Брюки',
      AppLanguage.english: 'Trousers',
      AppLanguage.kazakh: 'Шалбар',
    },
    'Юбки': {
      AppLanguage.russian: 'Юбки',
      AppLanguage.english: 'Skirts',
      AppLanguage.kazakh: 'Юбкалар',
    },
    'Лето': {
      AppLanguage.russian: 'Лето',
      AppLanguage.english: 'Summer',
      AppLanguage.kazakh: 'Жаз',
    },
    'Зима': {
      AppLanguage.russian: 'Зима',
      AppLanguage.english: 'Winter',
      AppLanguage.kazakh: 'Қыс',
    },
    'Весна': {
      AppLanguage.russian: 'Весна',
      AppLanguage.english: 'Spring',
      AppLanguage.kazakh: 'Көктем',
    },
  };

  return mapping[value]?[language] ?? value;
}

String localizedAvailabilityLabel(
  AppLanguage language, {
  required bool inStock,
  required bool preorder,
}) {
  if (inStock) {
    return tr(language, ru: 'В наличии', en: 'In Stock', kk: 'Қоймада бар');
  }
  if (preorder) {
    return tr(
      language,
      ru: 'Индивидуальный пошив 2-4 дня',
      en: 'Made to Order in 2-4 Days',
      kk: 'Жеке тігу 2-4 күн',
    );
  }
  return tr(
    language,
    ru: 'Ожидаем поступление',
    en: 'Awaiting Restock',
    kk: 'Күтілуде',
  );
}

String localizedMonthShort(AppLanguage language, int month) {
  const russian = <String>[
    'ЯНВ',
    'ФЕВ',
    'МАР',
    'АПР',
    'МАЙ',
    'ИЮН',
    'ИЮЛ',
    'АВГ',
    'СЕН',
    'ОКТ',
    'НОЯ',
    'ДЕК',
  ];
  const english = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  const kazakh = <String>[
    'ҚАҢ',
    'АҚП',
    'НАУ',
    'СӘУ',
    'МАМ',
    'МАУ',
    'ШІЛ',
    'ТАМ',
    'ҚЫР',
    'ҚАЗ',
    'ҚАР',
    'ЖЕЛ',
  ];

  if (language == AppLanguage.kazakh) {
    return kazakh[month - 1];
  }
  return language == AppLanguage.russian
      ? russian[month - 1]
      : english[month - 1];
}
