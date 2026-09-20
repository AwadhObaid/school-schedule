import 'package:shared_preferences/shared_preferences.dart';

class PinStore {
  static const _storageKey = 'settings_pin_v1';
  static const defaultPin = '0000';

  Future<String> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_storageKey)?.trim() ?? '';
    return isValid(value) ? value : defaultPin;
  }

  Future<void> save(String pin) async {
    if (!isValid(pin)) {
      throw ArgumentError('PIN must contain 4 to 12 digits.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, pin);
  }

  static bool isValid(String value) {
    return RegExp(r'^\d{4,12}$').hasMatch(value);
  }
}
