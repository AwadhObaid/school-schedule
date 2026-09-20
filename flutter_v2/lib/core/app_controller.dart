import 'package:flutter/foundation.dart';

import 'data/school_schedule_defaults.dart';
import 'models/notification_settings.dart';
import 'models/teacher_class.dart';
import 'services/teacher_notification_scheduler.dart';
import 'services/teacher_schedule_engine.dart';
import 'storage/notification_settings_store.dart';
import 'storage/teacher_schedule_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    TeacherScheduleStore? store,
    NotificationSettingsStore? notificationSettingsStore,
    TeacherNotificationScheduler? notificationScheduler,
  })  : _store = store ?? TeacherScheduleStore(),
        _notificationSettingsStore =
            notificationSettingsStore ?? NotificationSettingsStore(),
        _notificationScheduler =
            notificationScheduler ?? LocalTeacherNotificationScheduler();

  final TeacherScheduleStore _store;
  final NotificationSettingsStore _notificationSettingsStore;
  final TeacherNotificationScheduler _notificationScheduler;

  List<TeacherClass> _teacherClasses = const <TeacherClass>[];
  NotificationSettings _notificationSettings = const NotificationSettings();
  bool _initialized = false;
  bool _notificationBusy = false;
  String _notificationStatus = 'التنبيهات غير مفعلة';

  bool get initialized => _initialized;
  List<TeacherClass> get teacherClasses => List.unmodifiable(_teacherClasses);
  int get activeClassCount => _teacherClasses.where((item) => item.enabled).length;
  NotificationSettings get notificationSettings => _notificationSettings;
  bool get notificationBusy => _notificationBusy;
  String get notificationStatus => _notificationStatus;

  Future<void> initialize() async {
    _teacherClasses = await _store.load();
    _notificationSettings = await _notificationSettingsStore.load();

    await _notificationScheduler.initialize();

    if (_notificationSettings.enabled) {
      _notificationStatus = 'تنبيهات حصصي مفعلة';
      await _syncNotifications();
    }

    _initialized = true;
    notifyListeners();
  }

  TeacherClass? assignmentFor(int weekday, String periodId) {
    for (final item in _teacherClasses) {
      if (item.weekday == weekday && item.periodId == periodId && item.enabled) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsertTeacherClass(TeacherClass value) async {
    final updated = List<TeacherClass>.from(_teacherClasses);
    final index = updated.indexWhere(
      (item) => item.weekday == value.weekday && item.periodId == value.periodId,
    );

    if (index >= 0) {
      updated[index] = value;
    } else {
      updated.add(value);
    }

    updated.sort((a, b) {
      final day = _dayOrder(a.weekday).compareTo(_dayOrder(b.weekday));
      if (day != 0) return day;
      return a.periodId.compareTo(b.periodId);
    });

    _teacherClasses = List.unmodifiable(updated);
    await _store.save(_teacherClasses);
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> removeTeacherClass(int weekday, String periodId) async {
    _teacherClasses = List.unmodifiable(
      _teacherClasses.where(
        (item) => !(item.weekday == weekday && item.periodId == periodId),
      ),
    );
    await _store.save(_teacherClasses);
    await _syncNotifications();
    notifyListeners();
  }

  Future<bool> setNotificationSettings(NotificationSettings value) async {
    if (_notificationBusy) return false;

    _notificationBusy = true;
    notifyListeners();

    try {
      var next = value;

      if (value.enabled && !_notificationSettings.enabled) {
        final permissions = await _notificationScheduler.requestPermissions();

        if (!permissions.notificationsGranted) {
          next = value.copyWith(enabled: false);
          _notificationStatus =
              'لم يتم منح إذن الإشعارات. يمكنك المحاولة مرة أخرى من الإعدادات.';
          _notificationSettings = next;
          await _notificationSettingsStore.save(next);
          await _notificationScheduler.cancelTeacherNotifications();
          return false;
        }

        _notificationStatus = permissions.exactAlarmsGranted
            ? 'التنبيهات الدقيقة مفعلة'
            : 'التنبيهات مفعلة بوضع تقريبي لأن إذن التنبيه الدقيق غير متاح';
      } else if (!value.enabled) {
        _notificationStatus = 'التنبيهات غير مفعلة';
      } else if (value.enabled) {
        _notificationStatus = 'تنبيهات حصصي مفعلة';
      }

      _notificationSettings = next;
      await _notificationSettingsStore.save(next);

      if (next.enabled) {
        await _syncNotifications();
      } else {
        await _notificationScheduler.cancelTeacherNotifications();
      }

      return next.enabled == value.enabled;
    } finally {
      _notificationBusy = false;
      notifyListeners();
    }
  }

  Future<void> showTestNotification() async {
    if (!_notificationSettings.enabled || _notificationBusy) return;
    await _notificationScheduler.showTestNotification();
  }

  TeacherTimeline timelineAt(DateTime now) {
    return TeacherScheduleEngine(
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      assignments: _teacherClasses,
    ).evaluate(now);
  }

  Future<void> _syncNotifications() async {
    if (!_notificationSettings.enabled) return;

    await _notificationScheduler.sync(
      assignments: _teacherClasses,
      periods: SchoolScheduleDefaults.normalTeachingPeriods,
      settings: _notificationSettings,
    );
  }

  static int _dayOrder(int weekday) {
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
}
