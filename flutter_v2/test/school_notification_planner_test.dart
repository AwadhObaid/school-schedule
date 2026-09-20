import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/services/school_notification_planner.dart';

void main() {
  const planner = SchoolNotificationPlanner();

  test('builds legacy-equivalent weekly school notifications', () {
    final result = planner.build(
      schedule: SchoolScheduleDefaults.settings,
      enabled: true,
    );

    expect(result, hasLength(70));

    final assemblyStart = result.firstWhere((item) => item.id == 907000);
    expect(assemblyStart.kind, SchoolNotificationKind.start);
    expect(assemblyStart.weekday, DateTime.sunday);
    expect(assemblyStart.minutesOfDay, 7 * 60 + 30);
    expect(assemblyStart.title, contains('الطابور'));

    expect(
      result.where((item) => item.id == 907001),
      isEmpty,
      reason: 'Assembly ends exactly when P1 starts, so no redundant end alert.',
    );

    final p1End = result.firstWhere((item) => item.id == 907003);
    expect(p1End.kind, SchoolNotificationKind.end);
    expect(p1End.minutesOfDay, 8 * 60 + 20);
    expect(p1End.body, contains('الحصة الثانية'));

    final lastEnd = result.firstWhere((item) => item.id == 907015);
    expect(lastEnd.title, 'انتهى الدوام المدرسي');
    expect(lastEnd.minutesOfDay, 12 * 60);
  });

  test('returns no alerts when disabled', () {
    final result = planner.build(
      schedule: SchoolScheduleDefaults.settings,
      enabled: false,
    );

    expect(result, isEmpty);
  });

  test('Ramadan mode changes general notification times', () {
    final schedule =
        SchoolScheduleDefaults.settings.copyWith(ramadanMode: true);

    final result = planner.build(
      schedule: schedule,
      enabled: true,
    );

    final sundayAssembly =
        result.firstWhere((item) => item.id == 907000);
    expect(sundayAssembly.minutesOfDay, 8 * 60);

    final sundayP1 =
        result.firstWhere((item) => item.id == 907002);
    expect(sundayP1.minutesOfDay, 8 * 60 + 10);
  });
}
