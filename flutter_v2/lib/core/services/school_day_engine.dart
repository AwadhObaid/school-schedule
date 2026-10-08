import '../models/school_period.dart';
import '../models/school_schedule_settings.dart';

enum SchoolDayPhase {
  off,
  before,
  active,
  gap,
  ended,
}

class SchoolDayStatus {
  const SchoolDayStatus({
    required this.phase,
    required this.profileName,
    required this.periods,
    required this.current,
    required this.previous,
    required this.next,
    required this.currentStart,
    required this.currentEnd,
    required this.nextStart,
  });

  final SchoolDayPhase phase;
  final String? profileName;
  final List<SchoolPeriod> periods;
  final SchoolPeriod? current;
  final SchoolPeriod? previous;
  final SchoolPeriod? next;
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final DateTime? nextStart;

  bool get isSchoolDay => phase != SchoolDayPhase.off;
}

class SchoolDayEngine {
  const SchoolDayEngine({
    required this.scheduleSettings,
  });

  final SchoolScheduleSettings scheduleSettings;

  SchoolDayStatus evaluate(DateTime now) {
    final profile = scheduleSettings.profileForWeekday(now.weekday);
    if (profile == null || profile.periods.isEmpty) {
      return const SchoolDayStatus(
        phase: SchoolDayPhase.off,
        profileName: null,
        periods: <SchoolPeriod>[],
        current: null,
        previous: null,
        next: null,
        currentStart: null,
        currentEnd: null,
        nextStart: null,
      );
    }

    final periods = List<SchoolPeriod>.from(profile.periods)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final first = periods.first;
    final firstStart = _atMinutes(now, first.startMinutes);

    if (now.isBefore(firstStart)) {
      return SchoolDayStatus(
        phase: SchoolDayPhase.before,
        profileName: profile.name,
        periods: List<SchoolPeriod>.unmodifiable(periods),
        current: null,
        previous: null,
        next: first,
        currentStart: null,
        currentEnd: null,
        nextStart: firstStart,
      );
    }

    for (var index = 0; index < periods.length; index += 1) {
      final period = periods[index];
      final start = _atMinutes(now, period.startMinutes);
      final end = start.add(Duration(minutes: period.durationMinutes));

      if (!now.isBefore(start) && now.isBefore(end)) {
        final next = index + 1 < periods.length ? periods[index + 1] : null;
        return SchoolDayStatus(
          phase: SchoolDayPhase.active,
          profileName: profile.name,
          periods: List<SchoolPeriod>.unmodifiable(periods),
          current: period,
          previous: index > 0 ? periods[index - 1] : null,
          next: next,
          currentStart: start,
          currentEnd: end,
          nextStart: next == null ? null : _atMinutes(now, next.startMinutes),
        );
      }

      if (index + 1 < periods.length) {
        final next = periods[index + 1];
        final nextStart = _atMinutes(now, next.startMinutes);

        if (!now.isBefore(end) && now.isBefore(nextStart)) {
          return SchoolDayStatus(
            phase: SchoolDayPhase.gap,
            profileName: profile.name,
            periods: List<SchoolPeriod>.unmodifiable(periods),
            current: null,
            previous: period,
            next: next,
            currentStart: null,
            currentEnd: null,
            nextStart: nextStart,
          );
        }
      }
    }

    return SchoolDayStatus(
      phase: SchoolDayPhase.ended,
      profileName: profile.name,
      periods: List<SchoolPeriod>.unmodifiable(periods),
      current: null,
      previous: periods.last,
      next: null,
      currentStart: null,
      currentEnd: null,
      nextStart: null,
    );
  }

  static DateTime _atMinutes(DateTime date, int minutes) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }
}
