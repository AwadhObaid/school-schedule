import '../models/school_schedule_settings.dart';

class SchoolBellEngine {
  const SchoolBellEngine();

  String stateKeyAt({
    required SchoolScheduleSettings schedule,
    required DateTime now,
  }) {
    final profile = schedule.profileForWeekday(now.weekday);
    if (profile == null || profile.periods.isEmpty) return 'off';

    final periods = profile.periods;
    final secondsNow =
        now.hour * 3600 + now.minute * 60 + now.second;

    final firstStart = periods.first.startMinutes * 60;
    if (secondsNow < firstStart) return 'before';

    for (var index = 0; index < periods.length; index += 1) {
      final period = periods[index];
      final start = period.startMinutes * 60;
      final end = start + period.durationMinutes * 60;

      if (secondsNow >= start && secondsNow < end) {
        return 'period:${period.id}';
      }

      if (index < periods.length - 1) {
        final nextStart = periods[index + 1].startMinutes * 60;
        if (secondsNow >= end && secondsNow < nextStart) {
          return 'gap:${period.id}->${periods[index + 1].id}';
        }
      }
    }

    return 'ended';
  }
}
