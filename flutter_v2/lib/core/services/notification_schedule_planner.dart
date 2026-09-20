import '../models/notification_settings.dart';
import '../models/school_period.dart';
import '../models/teacher_class.dart';

enum TeacherNotificationKind {
  preAlert,
  start,
  end,
}

class PlannedTeacherNotification {
  const PlannedTeacherNotification({
    required this.id,
    required this.kind,
    required this.weekday,
    required this.minutesOfDay,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final TeacherNotificationKind kind;
  final int weekday;
  final int minutesOfDay;
  final String title;
  final String body;
  final String payload;
}

class NotificationSchedulePlanner {
  const NotificationSchedulePlanner();

  List<PlannedTeacherNotification> build({
    required List<TeacherClass> assignments,
    required Map<int, List<SchoolPeriod>> periodsByWeekday,
    required NotificationSettings settings,
  }) {
    if (!settings.enabled) return const <PlannedTeacherNotification>[];

    final active = <({TeacherClass assignment, SchoolPeriod period})>[];

    for (final assignment in assignments) {
      if (!assignment.enabled) continue;
      final periods = periodsByWeekday[assignment.weekday] ??
          const <SchoolPeriod>[];
      SchoolPeriod? period;
      for (final candidate in periods) {
        if (candidate.id == assignment.periodId) {
          period = candidate;
          break;
        }
      }
      if (period != null) {
        active.add((assignment: assignment, period: period));
      }
    }

    active.sort((a, b) {
      final day = _weekOrder(a.assignment.weekday)
          .compareTo(_weekOrder(b.assignment.weekday));
      if (day != 0) return day;
      return a.period.startMinutes.compareTo(b.period.startMinutes);
    });

    final result = <PlannedTeacherNotification>[];

    for (var index = 0; index < active.length; index += 1) {
      final item = active[index];
      final assignment = item.assignment;
      final period = item.period;
      final next = active.isEmpty ? null : active[(index + 1) % active.length];

      if (settings.preAlertMinutes > 0) {
        var weekday = assignment.weekday;
        var minutes = period.startMinutes - settings.preAlertMinutes;
        if (minutes < 0) {
          minutes += 24 * 60;
          weekday = _previousWeekday(weekday);
        }

        result.add(
          PlannedTeacherNotification(
            id: _id(assignment, TeacherNotificationKind.preAlert),
            kind: TeacherNotificationKind.preAlert,
            weekday: weekday,
            minutesOfDay: minutes,
            title: 'اقترب موعد ${period.name}',
            body: _joinBody(
              '${assignment.subject} • بعد ${settings.preAlertMinutes} دقائق',
              assignment.classroom,
            ),
            payload: 'teacher-class:${assignment.storageKey}:pre',
          ),
        );
      }

      if (settings.startAlert) {
        result.add(
          PlannedTeacherNotification(
            id: _id(assignment, TeacherNotificationKind.start),
            kind: TeacherNotificationKind.start,
            weekday: assignment.weekday,
            minutesOfDay: period.startMinutes,
            title: 'بدأت ${period.name}',
            body: _joinBody(
              '${assignment.subject} • مدتها ${period.durationMinutes} دقيقة',
              assignment.classroom,
            ),
            payload: 'teacher-class:${assignment.storageKey}:start',
          ),
        );
      }

      if (settings.endAlert) {
        final nextDescription = next == null
            ? null
            : 'القادمة: ${next.assignment.subject}${_optionalClassroom(next.assignment.classroom)}';
        result.add(
          PlannedTeacherNotification(
            id: _id(assignment, TeacherNotificationKind.end),
            kind: TeacherNotificationKind.end,
            weekday: assignment.weekday,
            minutesOfDay: period.endMinutes,
            title: 'انتهت ${period.name}',
            body: nextDescription ?? 'انتهى وقت ${assignment.subject}',
            payload: 'teacher-class:${assignment.storageKey}:end',
          ),
        );
      }
    }

    return List<PlannedTeacherNotification>.unmodifiable(result);
  }

  static int _id(
    TeacherClass assignment,
    TeacherNotificationKind kind,
  ) {
    final periodNumber =
        int.tryParse(assignment.periodId.replaceAll(RegExp(r'\D'), '')) ?? 0;
    return 300000 +
        (assignment.weekday * 1000) +
        (periodNumber * 10) +
        kind.index;
  }

  static int _previousWeekday(int weekday) {
    return weekday == DateTime.monday ? DateTime.sunday : weekday - 1;
  }

  static int _weekOrder(int weekday) {
    const order = <int>[
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];
    final index = order.indexOf(weekday);
    return index < 0 ? 99 : index;
  }

  static String _joinBody(String first, String? classroom) {
    final room = classroom?.trim();
    if (room == null || room.isEmpty) return first;
    return '$first • $room';
  }

  static String _optionalClassroom(String? classroom) {
    final room = classroom?.trim();
    if (room == null || room.isEmpty) return '';
    return ' • $room';
  }
}
