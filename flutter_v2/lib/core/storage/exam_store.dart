import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';

class ExamStore {
  static const storageKey = 'school_schedule_exams_v1';

  Future<List<Exam>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return <Exam>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Exam>[];

      return decoded
          .whereType<Map>()
          .map((item) => Exam.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty && item.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <Exam>[];
    }
  }

  Future<void> save(List<Exam> exams) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(exams.map((item) => item.toJson()).toList()),
    );
  }
}
