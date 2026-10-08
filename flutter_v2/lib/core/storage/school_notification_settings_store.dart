import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/school_notification_settings.dart';

class SchoolNotificationSettingsStore {
  static const _storageKey = 'school_notification_settings_v1';

  Future<SchoolNotificationSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const SchoolNotificationSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const SchoolNotificationSettings();
      }

      return SchoolNotificationSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const SchoolNotificationSettings();
    }
  }

  Future<void> save(SchoolNotificationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(settings.toJson()),
    );
  }
}
