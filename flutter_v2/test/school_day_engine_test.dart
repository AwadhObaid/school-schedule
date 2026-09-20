import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/services/school_day_engine.dart';

void main() {
  const engine = SchoolDayEngine(
    scheduleSettings: SchoolScheduleDefaults.settings,
  );

  test('detects before-school state', () {
    final status = engine.evaluate(DateTime(2026, 9, 20, 7, 20));

    expect(status.phase, SchoolDayPhase.before);
    expect(status.next?.id, 'assembly');
    expect(status.nextStart, DateTime(2026, 9, 20, 7, 30));
  });

  test('detects active school period', () {
    final status = engine.evaluate(DateTime(2026, 9, 20, 7, 35));

    expect(status.phase, SchoolDayPhase.active);
    expect(status.current?.id, 'assembly');
    expect(status.currentStart, DateTime(2026, 9, 20, 7, 30));
    expect(status.currentEnd, DateTime(2026, 9, 20, 7, 45));
  });

  test('detects gap between periods', () {
    final status = engine.evaluate(DateTime(2026, 9, 20, 8, 22));

    expect(status.phase, SchoolDayPhase.gap);
    expect(status.previous?.id, 'p1');
    expect(status.next?.id, 'p2');
    expect(status.nextStart, DateTime(2026, 9, 20, 8, 25));
  });

  test('detects school day ended', () {
    final status = engine.evaluate(DateTime(2026, 9, 20, 12, 15));

    expect(status.phase, SchoolDayPhase.ended);
    expect(status.previous?.id, 'p6');
  });

  test('returns off on Friday', () {
    final status = engine.evaluate(DateTime(2026, 9, 25, 9));

    expect(status.phase, SchoolDayPhase.off);
    expect(status.isSchoolDay, isFalse);
  });
}
