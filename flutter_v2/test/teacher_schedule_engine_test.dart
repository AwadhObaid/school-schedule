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

  test('detects current teacher class using normal schedule', () {
    const engine = TeacherScheduleEngine(
      scheduleSettings: SchoolScheduleDefaults.settings,
      assignments: assignments,
    );

    final timeline = engine.evaluate(DateTime(2026, 9, 20, 7, 50));

    expect(timeline.current?.assignment.subject, 'الرياضيات');
    expect(timeline.current?.period.id, 'p1');
    expect(timeline.next?.period.id, 'p2');
  });

  test('Ramadan mode changes teacher class times automatically', () {
    final engine = TeacherScheduleEngine(
      scheduleSettings:
          SchoolScheduleDefaults.settings.copyWith(ramadanMode: true),
      assignments: assignments,
    );

    final timeline = engine.evaluate(DateTime(2026, 9, 20, 8, 45));

    expect(timeline.current?.period.id, 'p2');
    expect(timeline.current?.start.hour, 8);
    expect(timeline.current?.start.minute, 40);
  });

  test('finds next class on the following school day', () {
    const engine = TeacherScheduleEngine(
      scheduleSettings: SchoolScheduleDefaults.settings,
      assignments: assignments,
    );

    final timeline = engine.evaluate(DateTime(2026, 9, 20, 12, 30));

    expect(timeline.current, isNull);
    expect(timeline.next?.assignment.subject, 'العلوم');
    expect(timeline.next?.start.weekday, DateTime.monday);
  });

  test('school day marked off does not produce teacher classes', () {
    const engine = TeacherScheduleEngine(
      scheduleSettings: SchoolScheduleDefaults.settings,
      assignments: <TeacherClass>[
        TeacherClass(
          weekday: DateTime.friday,
          periodId: 'p1',
          subject: 'الرياضيات',
        ),
      ],
    );

    final classes = engine.classesForDate(DateTime(2026, 9, 25, 8));

    expect(classes, isEmpty);
  });
}
