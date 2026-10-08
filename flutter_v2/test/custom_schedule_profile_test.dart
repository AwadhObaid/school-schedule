import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/school_period.dart';
import 'package:schedule/core/models/school_schedule_settings.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/teacher_schedule_engine.dart';

void main() {
  test('custom profile can be assigned to a weekday', () {
    const custom = SchoolScheduleProfile(
      id: 'custom_exam',
      name: 'جدول الاختبارات',
      periods: <SchoolPeriod>[
        SchoolPeriod(
          id: 'p1',
          name: 'الاختبار الأول',
          startMinutes: 9 * 60,
          durationMinutes: 60,
        ),
        SchoolPeriod(
          id: 'p2',
          name: 'الاختبار الثاني',
          startMinutes: 10 * 60 + 15,
          durationMinutes: 60,
        ),
      ],
    );

    final settings = SchoolScheduleDefaults.settings.copyWith(
      profiles: <String, SchoolScheduleProfile>{
        ...SchoolScheduleDefaults.settings.profiles,
        custom.id: custom,
      },
      weekdayMap: <int, String>{
        ...SchoolScheduleDefaults.settings.weekdayMap,
        DateTime.wednesday: custom.id,
      },
    );

    final engine = TeacherScheduleEngine(
      scheduleSettings: settings,
      assignments: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.wednesday,
          periodId: 'p1',
          subject: 'الرياضيات',
        ),
      ],
    );

    final timeline = engine.evaluate(DateTime(2026, 9, 23, 9, 15));

    expect(timeline.current?.assignment.subject, 'الرياضيات');
    expect(timeline.current?.period.name, 'الاختبار الأول');
    expect(timeline.current?.start.hour, 9);
    expect(timeline.current?.end.hour, 10);
  });

  test('Ramadan mode does not override a custom weekday profile', () {
    const custom = SchoolScheduleProfile(
      id: 'custom_short',
      name: 'دوام قصير',
      periods: <SchoolPeriod>[
        SchoolPeriod(
          id: 'p1',
          name: 'الحصة الأولى',
          startMinutes: 10 * 60,
          durationMinutes: 30,
        ),
      ],
    );

    final settings = SchoolScheduleDefaults.settings.copyWith(
      ramadanMode: true,
      profiles: <String, SchoolScheduleProfile>{
        ...SchoolScheduleDefaults.settings.profiles,
        custom.id: custom,
      },
      weekdayMap: <int, String>{
        ...SchoolScheduleDefaults.settings.weekdayMap,
        DateTime.sunday: custom.id,
      },
    );

    expect(
      settings.effectiveProfileIdForWeekday(DateTime.sunday),
      custom.id,
    );
    expect(
      settings.teachingPeriodsForWeekday(DateTime.sunday).single.startMinutes,
      10 * 60,
    );
  });
}
