import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avishu/shared/providers/app_settings.dart';

void main() {
  test('app settings toggles update state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appSettingsProvider.notifier);

    controller.setNotifications(false);
    controller.setProductionSound(false);
    controller.setCompactCards(true);

    final state = container.read(appSettingsProvider);
    expect(state.notificationsEnabled, isFalse);
    expect(state.productionSoundEnabled, isFalse);
    expect(state.compactCards, isTrue);
  });
}
