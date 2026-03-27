import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettingsState {
  final bool notificationsEnabled;
  final bool productionSoundEnabled;
  final bool compactCards;

  const AppSettingsState({
    this.notificationsEnabled = true,
    this.productionSoundEnabled = true,
    this.compactCards = false,
  });

  AppSettingsState copyWith({
    bool? notificationsEnabled,
    bool? productionSoundEnabled,
    bool? compactCards,
  }) {
    return AppSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      productionSoundEnabled:
          productionSoundEnabled ?? this.productionSoundEnabled,
      compactCards: compactCards ?? this.compactCards,
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
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );
