import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_appearance.dart';

class AppearanceStore {
  static const _storageKey = 'app_appearance_v1';

  Future<AppAppearance> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppAppearance.fromStorage(
      preferences.getString(_storageKey),
    );
  }

  Future<void> save(AppAppearance value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, value.storageValue);
  }
}
