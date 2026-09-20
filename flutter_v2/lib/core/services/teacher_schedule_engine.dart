import '../models/school_period.dart';
import '../models/school_schedule_settings.dart';
import '../models/teacher_class.dart';

class ScheduledTeacherClass {
  const ScheduledTeacherClass({
    required this.assignment,
    required this.period,
    required this.start,
    required this.end,
  });

  final TeacherClass assignment;
  final SchoolPeriod period;
  final DateTime start;
  final DateTime end;
}

class TeacherTimeline {
  const TeacherTimeline({
    required this.today,
    required this.current,
    required this.next,
  });

  final List<ScheduledTeacherClass> today;
  final ScheduledTeacherClass? current;
  final ScheduledTeacherClass? next;
}

class TeacherScheduleEngine {
  const TeacherScheduleEngine({
    required this.scheduleSettings,
    required this.assignments,
  });

  final SchoolScheduleSettings scheduleSettings;
  final List<TeacherClass> assignments;

  TeacherTimeline evaluate(DateTime now) {
    final today = classesForDate(now);

    ScheduledTeacherClass? current;
    for (final item in today) {
      if (!now.isBefore(item.start) && now.isBefore(item.end)) {
        current = item;
        break;
      }
    }

    ScheduledTeacherClass? next;
    for (final item in today) {
      if (item.start.isAfter(now)) {
        next = item;
        break;
      }
    }

    if (next == null) {
      for (var offset = 1; offset <= 7; offset += 1) {
        final date = DateTime(now.year, now.month, now.day + offset);
        final candidates = classesForDate(date);
        if (candidates.isNotEmpty) {
          next = candidates.first;
          break;
        }
      }
    }

    return TeacherTimeline(
      today: today,
      current: current,
      next: next,
    );
  }

  List<ScheduledTeacherClass> classesForDate(DateTime date) {
    final periods = scheduleSettings.teachingPeriodsForWeekday(date.weekday);
    final periodById = {for (final period in periods) period.id: period};
    final result = <ScheduledTeacherClass>[];

    for (final assignment in assignments) {
      if (!assignment.enabled || assignment.weekday != date.weekday) continue;
      final period = periodById[assignment.periodId];
      if (period == null) continue;

      final start = DateTime(
        date.year,
        date.month,
        date.day,
        period.startMinutes ~/ 60,
        period.startMinutes % 60,
      );
      final end = start.add(Duration(minutes: period.durationMinutes));

      result.add(
        ScheduledTeacherClass(
          assignment: assignment,
          period: period,
          start: start,
          end: end,
        ),
      );
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return List<ScheduledTeacherClass>.unmodifiable(result);
  }
}
