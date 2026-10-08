import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/storage/notification_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('notification settings persist locally', () async {
    final store = NotificationSettingsStore();

    await store.save(
      const NotificationSettings(
        enabled: true,
        preAlertMinutes: 10,
        startAlert: false,
        endAlert: true,
      ),
    );

    final loaded = await store.load();

    expect(loaded.enabled, isTrue);
    expect(loaded.preAlertMinutes, 10);
    expect(loaded.startAlert, isFalse);
    expect(loaded.endAlert, isTrue);
  });
}
