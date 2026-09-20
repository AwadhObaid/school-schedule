import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/school_schedule_defaults.dart';
import '../models/school_schedule_settings.dart';

class SchoolScheduleStore {
  static const _storageKey = 'school_schedule_settings_v1';

  Future<SchoolScheduleSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return SchoolScheduleDefaults.settings;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return SchoolScheduleDefaults.settings;

      final loaded = SchoolScheduleSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      return _mergeWithDefaults(loaded);
    } catch (_) {
      return SchoolScheduleDefaults.settings;
    }
  }

  Future<void> save(SchoolScheduleSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  static SchoolScheduleSettings _mergeWithDefaults(
    SchoolScheduleSettings loaded,
  ) {
    final defaults = SchoolScheduleDefaults.settings;

    final profiles = <String, SchoolScheduleProfile>{
      ...defaults.profiles,
      ...loaded.profiles,
    };

    final weekdayMap = <int, String>{
      ...defaults.weekdayMap,
      ...loaded.weekdayMap,
    };

    return SchoolScheduleSettings(
      ramadanMode: loaded.ramadanMode,
      weekdayMap: weekdayMap,
      profiles: profiles,
    );
  }
}
