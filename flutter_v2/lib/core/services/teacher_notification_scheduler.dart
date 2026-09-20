import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_settings.dart';
import '../models/school_period.dart';
import '../models/teacher_class.dart';
import 'notification_schedule_planner.dart';

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
  });

  Future<void> cancelTeacherNotifications();

  Future<void> showTestNotification();
}

class LocalTeacherNotificationScheduler
    implements TeacherNotificationScheduler {
  LocalTeacherNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationSchedulePlanner? planner,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _planner = planner ?? const NotificationSchedulePlanner();

  static const _channelId = 'teacher_class_alerts';
  static const _channelName = 'تنبيهات الحصص';
  static const _channelDescription =
      'تنبيهات ما قبل الحصة وبدايتها ونهايتها';

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationSchedulePlanner _planner;

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
            _channelId,
            _channelName,
            description: _channelDescription,
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

      final mode = _exactAlarmsGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_school',
        ),
      );

      final now = tz.TZDateTime.now(tz.local);

      for (final item in planned) {
        final scheduled = _nextOccurrence(
          now: now,
          weekday: item.weekday,
          minutesOfDay: item.minutesOfDay,
        );

        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: item.payload,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Notification sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> cancelTeacherNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final item in pending) {
        if (item.id >= 300000 && item.id < 400000) {
          await _plugin.cancel(id: item.id);
        }
      }
    } catch (error) {
      debugPrint('Teacher notification cancellation skipped: $error');
    }
  }

  @override
  Future<void> showTestNotification() async {
    await initialize();

    try {
      await _plugin.show(
        id: 399999,
        title: 'اختبار تنبيهات حصصي',
        body: 'التنبيهات تعمل بنجاح على هذا الجهاز.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_school',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Test notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
