import 'package:flutter/foundation.dart';

import 'data/school_schedule_defaults.dart';
import 'models/teacher_class.dart';
import 'services/teacher_schedule_engine.dart';
import 'storage/teacher_schedule_store.dart';

class AppController extends ChangeNotifier {
  AppController({TeacherScheduleStore? store})
      : _store = store ?? TeacherScheduleStore();

  final TeacherScheduleStore _store;

  List<TeacherClass> _teacherClasses = const <TeacherClass>[];
  bool _initialized = false;

  bool get initialized => _initialized;
  List<TeacherClass> get teacherClasses => List.unmodifiable(_teacherClasses);
  int get activeClassCount => _teacherClasses.where((item) => item.enabled).length;

  Future<void> initialize() async {
    _teacherClasses = await _store.load();
    _initialized = true;
    notifyListeners();
  }

  TeacherClass? assignmentFor(int weekday, String periodId) {
    for (final item in _teacherClasses) {
      if (item.weekday == weekday && item.periodId == periodId && item.enabled) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsertTeacherClass(TeacherClass value) async {
    final updated = List<TeacherClass>.from(_teacherClasses);
    final index = updated.indexWhere(
      (item) => item.weekday == value.weekday && item.periodId == value.periodId,
    );

    if (index >= 0) {
      updated[index] = value;
    } else {
      updated.add(value);
    }

    updated.sort((a, b) {
      final day = _dayOrder(a.weekday).compareTo(_dayOrder(b.weekday));
      if (day != 0) return day;
      return a.periodId.compareTo(b.periodId);
    });

    _teacherClasses = List.unmodifiable(updated);
    await _store.save(_teacherClasses);
    notifyListeners();
  }

  Future<void> removeTeacherClass(int weekday, String periodId) async {
    _teacherClasses = List.unmodifiable(
      _teacherClasses.where(
        (item) => !(item.weekday == weekday && item.periodId == periodId),
      ),
    );
    await _store.save(_teacherClasses);
    notifyListeners();
  }

  TeacherTimeline timelineAt(DateTime now) {
    return TeacherScheduleEngine(
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      assignments: _teacherClasses,
    ).evaluate(now);
  }

  static int _dayOrder(int weekday) {
    const order = <int>[
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];
    final index = order.indexOf(weekday);
    return index < 0 ? 99 : index;
  }
}
