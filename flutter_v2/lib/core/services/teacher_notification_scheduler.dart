import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_settings.dart';
import '../models/school_period.dart';
import '../models/school_schedule_settings.dart';
import '../models/teacher_class.dart';
import 'notification_schedule_planner.dart';
import 'school_notification_planner.dart';

class NotificationPermissionResult {
  const NotificationPermissionResult({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
}

abstract class TeacherNotificationScheduler {
  Future<void> initialize();

  Future<NotificationPermissionResult> requestPermissions();

  Future<void> sync({
    required List<TeacherClass> assignments,
    required Map<int, List<SchoolPeriod>> periodsByWeekday,
    required NotificationSettings settings,
    String? androidChannelId,
  });

  Future<void> syncSchoolSchedule({
    required SchoolScheduleSettings schedule,
    required bool enabled,
    String? androidChannelId,
  });

  Future<void> cancelTeacherNotifications();

  Future<void> cancelSchoolScheduleNotifications();

  Future<bool> showTestNotification({String? androidChannelId});

  Future<bool> showSchoolScheduleTestNotification({
    String? androidChannelId,
  });
}

class LocalTeacherNotificationScheduler
    implements TeacherNotificationScheduler {
  LocalTeacherNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationSchedulePlanner? planner,
    SchoolNotificationPlanner? schoolPlanner,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _planner = planner ?? const NotificationSchedulePlanner(),
        _schoolPlanner = schoolPlanner ?? const SchoolNotificationPlanner();

  static const _teacherChannelId = 'teacher_class_alerts';
  static const _teacherChannelName = 'تنبيهات حصصي';
  static const _teacherChannelDescription =
      'تنبيهات ما قبل الحصة وبدايتها ونهايتها';

  static const _schoolChannelId = 'school_schedule_alerts';
  static const _schoolChannelName = 'تنبيهات الجدول المدرسي';
  static const _schoolChannelDescription =
      'تنبيهات بداية ونهاية جميع فترات الدوام المدرسي';

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationSchedulePlanner _planner;
  final SchoolNotificationPlanner _schoolPlanner;

  bool _initialized = false;
  bool _exactAlarmsGranted = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      final zoneInfo = await FlutterTimezone.getLocalTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(zoneInfo.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      const androidSettings = AndroidInitializationSettings('ic_stat_school');
      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(settings: settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _teacherChannelId,
            _teacherChannelName,
            description: _teacherChannelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _schoolChannelId,
            _schoolChannelName,
            description: _schoolChannelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        _exactAlarmsGranted =
            await android.canScheduleExactNotifications() ?? false;
      }

      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Notification initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
    }
  }

  @override
  Future<NotificationPermissionResult> requestPermissions() async {
    await initialize();

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android == null) {
        return const NotificationPermissionResult(
          notificationsGranted: true,
          exactAlarmsGranted: false,
        );
      }

      final notificationsGranted =
          await android.requestNotificationsPermission() ?? false;

      var exactGranted =
          await android.canScheduleExactNotifications() ?? false;
      if (!exactGranted) {
        await android.requestExactAlarmsPermission();
        exactGranted =
            await android.canScheduleExactNotifications() ?? false;
      }

      _exactAlarmsGranted = exactGranted;

      return NotificationPermissionResult(
        notificationsGranted: notificationsGranted,
        exactAlarmsGranted: exactGranted,
      );
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const NotificationPermissionResult(
        notificationsGranted: false,
        exactAlarmsGranted: false,
      );
    }
  }

  @override
  Future<void> sync({
    required List<TeacherClass> assignments,
    required Map<int, List<SchoolPeriod>> periodsByWeekday,
    required NotificationSettings settings,
    String? androidChannelId,
  }) async {
    await initialize();

    try {
      await cancelTeacherNotifications();
      if (!settings.enabled) return;

      final planned = _planner.build(
        assignments: assignments,
        periodsByWeekday: periodsByWeekday,
        settings: settings,
      );

      final details = _details(
        channelId: androidChannelId,
        fallbackChannelId: _teacherChannelId,
        channelName: _teacherChannelName,
        channelDescription: _teacherChannelDescription,
      );

      final now = tz.TZDateTime.now(tz.local);

      for (final item in planned) {
        await _scheduleWeekly(
          id: item.id,
          title: item.title,
          body: item.body,
          payload: item.payload,
          weekday: item.weekday,
          minutesOfDay: item.minutesOfDay,
          details: details,
          now: now,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Teacher notification sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> syncSchoolSchedule({
    required SchoolScheduleSettings schedule,
    required bool enabled,
    String? androidChannelId,
  }) async {
    await initialize();

    try {
      await cancelSchoolScheduleNotifications();
      if (!enabled) return;

      final planned = _schoolPlanner.build(
        schedule: schedule,
        enabled: enabled,
      );

      final details = _details(
        channelId: androidChannelId,
        fallbackChannelId: _schoolChannelId,
        channelName: _schoolChannelName,
        channelDescription: _schoolChannelDescription,
      );

      final now = tz.TZDateTime.now(tz.local);

      for (final item in planned) {
        await _scheduleWeekly(
          id: item.id,
          title: item.title,
          body: item.body,
          payload: item.payload,
          weekday: item.weekday,
          minutesOfDay: item.minutesOfDay,
          details: details,
          now: now,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('School notification sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> cancelTeacherNotifications() async {
    await _cancelRange(300000, 400000, 'teacher');
  }

  @override
  Future<void> cancelSchoolScheduleNotifications() async {
    await _cancelRange(900000, 910000, 'school');
    try {
      await _plugin.cancel(id: 899999);
    } catch (_) {
      // Best effort.
    }
  }

  @override
  Future<bool> showTestNotification({String? androidChannelId}) async {
    await initialize();

    try {
      if (!await _ensureDisplayPermission()) return false;

      await _plugin.show(
        id: 399999,
        title: 'اختبار تنبيهات حصصي',
        body: 'تنبيهات حصصك الشخصية تعمل بنجاح على هذا الجهاز.',
        notificationDetails: _details(
          channelId: androidChannelId,
          fallbackChannelId: _teacherChannelId,
          channelName: _teacherChannelName,
          channelDescription: _teacherChannelDescription,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Teacher test notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> showSchoolScheduleTestNotification({
    String? androidChannelId,
  }) async {
    await initialize();

    try {
      if (!await _ensureDisplayPermission()) return false;

      await _plugin.show(
        id: 899999,
        title: 'اختبار تنبيهات الجدول المدرسي',
        body: 'تنبيهات الفترات العامة تعمل بنجاح على هذا الجهاز.',
        notificationDetails: _details(
          channelId: androidChannelId,
          fallbackChannelId: _schoolChannelId,
          channelName: _schoolChannelName,
          channelDescription: _schoolChannelDescription,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('School test notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _ensureDisplayPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    try {
      return await android.requestNotificationsPermission() ?? true;
    } catch (error, stackTrace) {
      debugPrint('Notification display permission check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  NotificationDetails _details({
    required String? channelId,
    required String fallbackChannelId,
    required String channelName,
    required String channelDescription,
  }) {
    final resolvedChannelId = (channelId ?? '').trim().isEmpty
        ? fallbackChannelId
        : channelId!.trim();

    return NotificationDetails(
      android: AndroidNotificationDetails(
        resolvedChannelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_school',
      ),
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required String payload,
    required int weekday,
    required int minutesOfDay,
    required NotificationDetails details,
    required tz.TZDateTime now,
  }) async {
    final scheduled = _nextOccurrence(
      now: now,
      weekday: weekday,
      minutesOfDay: minutesOfDay,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: _exactAlarmsGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _cancelRange(
    int lowerInclusive,
    int upperExclusive,
    String label,
  ) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final item in pending) {
        if (item.id >= lowerInclusive && item.id < upperExclusive) {
          await _plugin.cancel(id: item.id);
        }
      }
    } catch (error) {
      debugPrint('$label notification cancellation skipped: $error');
    }
  }

  static tz.TZDateTime _nextOccurrence({
    required tz.TZDateTime now,
    required int weekday,
    required int minutesOfDay,
  }) {
    final hour = minutesOfDay ~/ 60;
    final minute = minutesOfDay % 60;

    for (var offset = 0; offset <= 7; offset += 1) {
      final date = now.add(Duration(days: offset));
      if (date.weekday != weekday) continue;

      final candidate = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      if (candidate.isAfter(now)) return candidate;
    }

    final fallback = now.add(const Duration(days: 7));
    return tz.TZDateTime(
      tz.local,
      fallback.year,
      fallback.month,
      fallback.day,
      hour,
      minute,
    );
  }
}
