import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/notification_schedule_planner.dart';

void main() {
  const planner = NotificationSchedulePlanner();

  test('builds pre, start and end alerts for an enabled teacher class', () {
    final result = planner.build(
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p2',
          subject: 'اللغة الإنجليزية',
          classroom: 'الصف 8 / 2',
        ),
      ],
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      settings: const NotificationSettings(
        enabled: true,
        preAlertMinutes: 5,
        startAlert: true,
        endAlert: true,
      ),
    );

    expect(result, hasLength(3));

    final pre = result.firstWhere(
      (item) => item.kind == TeacherNotificationKind.preAlert,
    );
    final start = result.firstWhere(
      (item) => item.kind == TeacherNotificationKind.start,
    );
    final end = result.firstWhere(
      (item) => item.kind == TeacherNotificationKind.end,
    );

    expect(pre.weekday, DateTime.sunday);
    expect(pre.minutesOfDay, 8 * 60 + 20);
    expect(start.minutesOfDay, 8 * 60 + 25);
    expect(end.minutesOfDay, 9 * 60);
    expect(start.body, contains('اللغة الإنجليزية'));
    expect(start.body, contains('الصف 8 / 2'));
  });

  test('returns no planned alerts when teacher notifications are disabled', () {
    final result = planner.build(
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p1',
          subject: 'الرياضيات',
        ),
      ],
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      settings: const NotificationSettings(enabled: false),
    );

    expect(result, isEmpty);
  });

  test('respects disabled start and end alert switches', () {
    final result = planner.build(
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.monday,
          periodId: 'p3',
          subject: 'العلوم',
        ),
      ],
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      settings: const NotificationSettings(
        enabled: true,
        preAlertMinutes: 10,
        startAlert: false,
        endAlert: false,
      ),
    );

    expect(result, hasLength(1));
    expect(result.single.kind, TeacherNotificationKind.preAlert);
    expect(result.single.minutesOfDay, 8 * 60 + 55);
  });
}
