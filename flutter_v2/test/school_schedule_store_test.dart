import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/school_schedule_settings.dart';
import 'package:schedule/core/storage/school_schedule_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('school schedule settings persist locally', () async {
    final store = SchoolScheduleStore();
    const defaults = SchoolScheduleDefaults.settings;
    final normal = defaults.profiles[SchoolScheduleSettings.normalProfileId]!;
    final periods = List.of(normal.periods);
    final p1Index = periods.indexWhere((item) => item.id == 'p1');
    periods[p1Index] = periods[p1Index].copyWith(
      startMinutes: 8 * 60,
      durationMinutes: 40,
    );

    final changed = defaults.copyWith(
      ramadanMode: true,
      profiles: <String, SchoolScheduleProfile>{
        ...defaults.profiles,
        SchoolScheduleSettings.normalProfileId:
            normal.copyWith(periods: periods),
      },
    );

    await store.save(changed);
    final loaded = await store.load();

    expect(loaded.ramadanMode, isTrue);
    final loadedP1 = loaded
        .profiles[SchoolScheduleSettings.normalProfileId]!
        .periods
        .firstWhere((item) => item.id == 'p1');
    expect(loadedP1.startMinutes, 8 * 60);
    expect(loadedP1.durationMinutes, 40);
  });

  test('defaults keep Friday and Saturday off', () async {
    final store = SchoolScheduleStore();
    final loaded = await store.load();

    expect(
      loaded.effectiveProfileIdForWeekday(DateTime.friday),
      SchoolScheduleSettings.offProfileId,
    );
    expect(
      loaded.effectiveProfileIdForWeekday(DateTime.saturday),
      SchoolScheduleSettings.offProfileId,
    );
  });
}
