import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bell_settings.dart';

class BellSettingsStore {
  static const _storageKey = 'school_bell_settings_v1';

  Future<BellSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const BellSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const BellSettings();
      return BellSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const BellSettings();
    }
  }

  Future<void> save(BellSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(settings.toJson()),
    );
  }
}
