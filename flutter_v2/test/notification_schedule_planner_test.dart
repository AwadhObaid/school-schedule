import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/models/school_period.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/notification_schedule_planner.dart';

void main() {
  const planner = NotificationSchedulePlanner();

  Map<int, List<SchoolPeriod>> normalWeek() {
    return <int, List<SchoolPeriod>>{
      DateTime.sunday:
          SchoolScheduleDefaults.settings.teachingPeriodsForWeekday(
        DateTime.sunday,
      ),
      DateTime.monday:
          SchoolScheduleDefaults.settings.teachingPeriodsForWeekday(
        DateTime.monday,
      ),
    };
  }

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
      periodsByWeekday: normalWeek(),
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

    expect(pre.minutesOfDay, 8 * 60 + 20);
    expect(start.minutesOfDay, 8 * 60 + 25);
    expect(end.minutesOfDay, 9 * 60);
  });

  test('uses Ramadan period times supplied for that weekday', () {
    final ramadan =
        SchoolScheduleDefaults.settings.copyWith(ramadanMode: true);

    final result = planner.build(
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p2',
          subject: 'اللغة الإنجليزية',
        ),
      ],
      periodsByWeekday: <int, List<SchoolPeriod>>{
        DateTime.sunday:
            ramadan.teachingPeriodsForWeekday(DateTime.sunday),
      },
      settings: const NotificationSettings(
        enabled: true,
        preAlertMinutes: 5,
        startAlert: true,
        endAlert: false,
      ),
    );

    expect(result, hasLength(2));
    final start = result.firstWhere(
      (item) => item.kind == TeacherNotificationKind.start,
    );
    expect(start.minutesOfDay, 8 * 60 + 40);
  });

  test('returns no planned alerts when notifications are disabled', () {
    final result = planner.build(
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p1',
          subject: 'الرياضيات',
        ),
      ],
      periodsByWeekday: normalWeek(),
      settings: const NotificationSettings(enabled: false),
    );

    expect(result, isEmpty);
  });
}
