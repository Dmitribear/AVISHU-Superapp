import '../../features/auth/domain/user_role.dart';

enum AppLanguage { russian, english }

enum CatalogCardSize { compact, standard, large }

String tr(AppLanguage language, {required String ru, required String en}) {
  return language == AppLanguage.russian ? ru : en;
}

String appLanguageLabel(AppLanguage language) {
  switch (language) {
    case AppLanguage.russian:
      return 'RU';
    case AppLanguage.english:
      return 'EN';
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
      return tr(language, ru: 'КЛИЕНТ', en: 'CLIENT');
    case UserRole.franchisee:
      return tr(language, ru: 'ФРАНЧАЙЗИ', en: 'FRANCHISEE');
    case UserRole.production:
      return tr(language, ru: 'ПРОИЗВОДСТВО', en: 'FACTORY');
    case UserRole.admin:
      return 'ADMIN';
  }
}

String localizeCatalogSection(AppLanguage language, String value) {
  const mapping = <String, Map<AppLanguage, String>>{
    'Новинки': {AppLanguage.russian: 'Новинки', AppLanguage.english: 'New In'},
    'Верхняя одежда': {
      AppLanguage.russian: 'Верхняя одежда',
      AppLanguage.english: 'Outerwear',
    },
    'Кардиганы и кофты': {
      AppLanguage.russian: 'Кардиганы и кофты',
      AppLanguage.english: 'Cardigans & Tops',
    },
    'Костюмы': {AppLanguage.russian: 'Костюмы', AppLanguage.english: 'Suits'},
    'База': {AppLanguage.russian: 'База', AppLanguage.english: 'Essentials'},
    'Брюки': {AppLanguage.russian: 'Брюки', AppLanguage.english: 'Trousers'},
    'Юбки': {AppLanguage.russian: 'Юбки', AppLanguage.english: 'Skirts'},
    'Лето': {AppLanguage.russian: 'Лето', AppLanguage.english: 'Summer'},
    'Зима': {AppLanguage.russian: 'Зима', AppLanguage.english: 'Winter'},
    'Весна': {AppLanguage.russian: 'Весна', AppLanguage.english: 'Spring'},
  };

  return mapping[value]?[language] ?? value;
}

String localizedAvailabilityLabel(
  AppLanguage language, {
  required bool inStock,
  required bool preorder,
}) {
  if (inStock) {
    return tr(language, ru: 'В наличии', en: 'In Stock');
  }
  if (preorder) {
    return tr(
      language,
      ru: 'Индивидуальный пошив 2-4 дня',
      en: 'Made to Order in 2-4 Days',
    );
  }
  return tr(language, ru: 'Ожидаем поступление', en: 'Awaiting Restock');
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

  return language == AppLanguage.russian
      ? russian[month - 1]
      : english[month - 1];
}
