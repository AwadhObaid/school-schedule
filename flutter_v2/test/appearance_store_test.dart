import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/app_appearance.dart';
import 'package:schedule/core/storage/appearance_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('appearance defaults to system and persists dark mode', () async {
    final store = AppearanceStore();

    expect(await store.load(), AppAppearance.system);

    await store.save(AppAppearance.dark);
    expect(await store.load(), AppAppearance.dark);
  });
}
