import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localization.dart';

class AppSettingsState {
  final bool notificationsEnabled;
  final bool productionSoundEnabled;
  final bool compactCards;
  final AppLanguage language;
  final CatalogCardSize catalogCardSize;

  const AppSettingsState({
    this.notificationsEnabled = true,
    this.productionSoundEnabled = true,
    this.compactCards = false,
    this.language = AppLanguage.russian,
    this.catalogCardSize = CatalogCardSize.standard,
  });

  AppSettingsState copyWith({
    bool? notificationsEnabled,
    bool? productionSoundEnabled,
    bool? compactCards,
    AppLanguage? language,
    CatalogCardSize? catalogCardSize,
  }) {
    return AppSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      productionSoundEnabled:
          productionSoundEnabled ?? this.productionSoundEnabled,
      compactCards: compactCards ?? this.compactCards,
      language: language ?? this.language,
      catalogCardSize: catalogCardSize ?? this.catalogCardSize,
    );
  }
}

class AppSettingsController extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() => const AppSettingsState();

  void setNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void setProductionSound(bool value) {
    state = state.copyWith(productionSoundEnabled: value);
  }

  void setCompactCards(bool value) {
    state = state.copyWith(compactCards: value);
  }

  void setLanguage(AppLanguage value) {
    state = state.copyWith(language: value);
  }

  void setCatalogCardSize(CatalogCardSize value) {
    state = state.copyWith(catalogCardSize: value);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );
