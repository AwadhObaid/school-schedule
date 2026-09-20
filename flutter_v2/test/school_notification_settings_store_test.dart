import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/school_notification_settings.dart';
import 'package:schedule/core/storage/school_notification_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('general school notifications default to disabled', () async {
    final store = SchoolNotificationSettingsStore();
    final loaded = await store.load();

    expect(loaded.enabled, isFalse);
  });

  test('general school notification setting persists', () async {
    final store = SchoolNotificationSettingsStore();

    await store.save(
      const SchoolNotificationSettings(enabled: true),
    );

    final loaded = await store.load();
    expect(loaded.enabled, isTrue);
  });
}
