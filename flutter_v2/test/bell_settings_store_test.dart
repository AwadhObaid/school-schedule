import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/bell_settings.dart';
import 'package:schedule/core/storage/bell_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('bell settings persist locally', () async {
    final store = BellSettingsStore();

    await store.save(
      const BellSettings(
        enabled: true,
        ringtoneUri: 'content://example/ringtones/bell.mp3',
        ringtoneName: 'bell.mp3',
        volume: 65,
      ),
    );

    final loaded = await store.load();

    expect(loaded.enabled, isTrue);
    expect(loaded.ringtoneUri, contains('bell.mp3'));
    expect(loaded.ringtoneName, 'bell.mp3');
    expect(loaded.volume, 65);
  });

  test('bell volume is clamped to valid range', () {
    final settings = BellSettings.fromJson(
      <String, dynamic>{
        'enabled': false,
        'ringtoneUri': '',
        'ringtoneName': '',
        'volume': 160,
      },
    );

    expect(settings.volume, 100);
    expect(settings.ringtoneName, 'نغمة النظام');
  });
}
