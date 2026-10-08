import '../models/school_schedule_settings.dart';
import '../utils/arabic_format.dart';

enum SchoolNotificationKind {
  start,
  end,
}

class PlannedSchoolNotification {
  const PlannedSchoolNotification({
    required this.id,
    required this.kind,
    required this.weekday,
    required this.minutesOfDay,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final SchoolNotificationKind kind;
  final int weekday;
  final int minutesOfDay;
  final String title;
  final String body;
  final String payload;
}

class SchoolNotificationPlanner {
  const SchoolNotificationPlanner();

  List<PlannedSchoolNotification> build({
    required SchoolScheduleSettings schedule,
    required bool enabled,
  }) {
    if (!enabled) return const <PlannedSchoolNotification>[];

    final result = <PlannedSchoolNotification>[];

    for (final weekday in const <int>[
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ]) {
      final profile = schedule.profileForWeekday(weekday);
      if (profile == null || profile.periods.isEmpty) continue;

      final periods = List.of(profile.periods)
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      for (var index = 0; index < periods.length; index += 1) {
        final period = periods[index];
        final next = index + 1 < periods.length ? periods[index + 1] : null;
        final baseId = 900000 + weekday * 1000 + index * 2;

        result.add(
          PlannedSchoolNotification(
            id: baseId,
            kind: SchoolNotificationKind.start,
            weekday: weekday,
            minutesOfDay: period.startMinutes,
            title: 'بدأت الآن: ${period.name}',
            body:
                'ينتهي وقت ${period.name} الساعة ${ArabicFormat.minutesClock(period.endMinutes)}',
            payload: 'school-period:$weekday:${period.id}:start',
          ),
        );

        final shouldScheduleEnd =
            next == null || next.startMinutes != period.endMinutes;

        if (!shouldScheduleEnd) continue;

        var endWeekday = weekday;
        var endMinutes = period.endMinutes;

        if (endMinutes >= 24 * 60) {
          endMinutes = 0;
          endWeekday = _nextWeekday(weekday);
        }

        result.add(
          PlannedSchoolNotification(
            id: baseId + 1,
            kind: SchoolNotificationKind.end,
            weekday: endWeekday,
            minutesOfDay: endMinutes,
            title: next == null
                ? 'انتهى الدوام المدرسي'
                : 'انتهت ${period.name}',
            body: next == null
                ? 'انتهت جميع الفترات والحصص لهذا اليوم.'
                : 'الفترة القادمة (${next.name}) تبدأ الساعة ${ArabicFormat.minutesClock(next.startMinutes)}',
            payload: 'school-period:$weekday:${period.id}:end',
          ),
        );
      }
    }

    return List<PlannedSchoolNotification>.unmodifiable(result);
  }

  static int _nextWeekday(int weekday) {
    if (weekday == DateTime.sunday) return DateTime.monday;
    return weekday + 1;
  }
}
