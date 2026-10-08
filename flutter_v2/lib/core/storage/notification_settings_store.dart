import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_settings.dart';

class NotificationSettingsStore {
  static const _storageKey = 'teacher_notification_settings_v1';

  Future<NotificationSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const NotificationSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const NotificationSettings();
      return NotificationSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> save(NotificationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(settings.toJson()),
    );
  }
}
