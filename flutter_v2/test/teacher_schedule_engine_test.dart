import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/teacher_schedule_engine.dart';

void main() {
  const assignments = <TeacherClass>[
    TeacherClass(
      weekday: DateTime.sunday,
      periodId: 'p1',
      subject: 'الرياضيات',
    ),
    TeacherClass(
      weekday: DateTime.sunday,
      periodId: 'p2',
      subject: 'اللغة الإنجليزية',
      classroom: 'الصف 8 / 2',
    ),
    TeacherClass(
      weekday: DateTime.monday,
      periodId: 'p3',
      subject: 'العلوم',
    ),
  ];

  const engine = TeacherScheduleEngine(
    periods: SchoolScheduleDefaults.normalTeachingPeriods,
    assignments: assignments,
  );

  test('detects current teacher class and the following class', () {
    final timeline = engine.evaluate(DateTime(2026, 9, 20, 7, 50));

    expect(timeline.current?.assignment.subject, 'الرياضيات');
    expect(timeline.current?.period.id, 'p1');
    expect(timeline.next?.period.id, 'p2');
  });

  test('detects free time between two teacher classes', () {
    final timeline = engine.evaluate(DateTime(2026, 9, 20, 8, 22));

    expect(timeline.current, isNull);
    expect(timeline.next?.period.id, 'p2');
  });

  test('finds next class on the following school day', () {
    final timeline = engine.evaluate(DateTime(2026, 9, 20, 12, 30));

    expect(timeline.current, isNull);
    expect(timeline.next?.assignment.subject, 'العلوم');
    expect(timeline.next?.start.weekday, DateTime.monday);
  });
}
