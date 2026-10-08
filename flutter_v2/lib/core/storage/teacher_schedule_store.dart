import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/teacher_class.dart';

class TeacherScheduleStore {
  static const _storageKey = 'teacher_schedule_v1';

  Future<List<TeacherClass>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return <TeacherClass>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <TeacherClass>[];

      return decoded
          .whereType<Map>()
          .map((item) => TeacherClass.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.periodId.isNotEmpty && item.subject.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return <TeacherClass>[];
    }
  }

  Future<void> save(List<TeacherClass> classes) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = classes.map((item) => item.toJson()).toList(growable: false);
    await preferences.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
