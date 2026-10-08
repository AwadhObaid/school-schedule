import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/services/school_bell_engine.dart';

void main() {
  const engine = SchoolBellEngine();

  test('detects normal school period state transitions', () {
    const schedule = SchoolScheduleDefaults.settings;

    expect(
      engine.stateKeyAt(
        schedule: schedule,
        now: DateTime(2026, 9, 20, 7, 20),
      ),
      'before',
    );

    expect(
      engine.stateKeyAt(
        schedule: schedule,
        now: DateTime(2026, 9, 20, 7, 35),
      ),
      'period:assembly',
    );

    expect(
      engine.stateKeyAt(
        schedule: schedule,
        now: DateTime(2026, 9, 20, 7, 50),
      ),
      'period:p1',
    );

    expect(
      engine.stateKeyAt(
        schedule: schedule,
        now: DateTime(2026, 9, 20, 8, 21),
      ),
      'gap:p1->p2',
    );
  });

  test('uses Ramadan profile when Ramadan mode is enabled', () {
    final schedule =
        SchoolScheduleDefaults.settings.copyWith(ramadanMode: true);

    expect(
      engine.stateKeyAt(
        schedule: schedule,
        now: DateTime(2026, 9, 20, 8, 15),
      ),
      'period:p1',
    );
  });

  test('returns off on a configured holiday', () {
    expect(
      engine.stateKeyAt(
        schedule: SchoolScheduleDefaults.settings,
        now: DateTime(2026, 9, 25, 9),
      ),
      'off',
    );
  });
}
