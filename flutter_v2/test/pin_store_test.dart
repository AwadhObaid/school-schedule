import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/storage/pin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default settings PIN is 0000', () async {
    final store = PinStore();
    expect(await store.load(), '0000');
  });

  test('PIN persists and must contain 4 to 12 digits', () async {
    final store = PinStore();

    expect(PinStore.isValid('1234'), isTrue);
    expect(PinStore.isValid('123456789012'), isTrue);
    expect(PinStore.isValid('123'), isFalse);
    expect(PinStore.isValid('12ab'), isFalse);

    await store.save('2468');
    expect(await store.load(), '2468');
  });
}
