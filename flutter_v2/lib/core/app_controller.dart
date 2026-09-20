import 'package:flutter/foundation.dart';

import 'data/school_schedule_defaults.dart';
import 'models/notification_settings.dart';
import 'models/school_period.dart';
import 'models/school_schedule_settings.dart';
import 'models/teacher_class.dart';
import 'services/teacher_notification_scheduler.dart';
import 'services/teacher_schedule_engine.dart';
import 'storage/notification_settings_store.dart';
import 'storage/school_schedule_store.dart';
import 'storage/teacher_schedule_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    TeacherScheduleStore? store,
    SchoolScheduleStore? schoolScheduleStore,
    NotificationSettingsStore? notificationSettingsStore,
    TeacherNotificationScheduler? notificationScheduler,
  })  : _store = store ?? TeacherScheduleStore(),
        _schoolScheduleStore = schoolScheduleStore ?? SchoolScheduleStore(),
        _notificationSettingsStore =
            notificationSettingsStore ?? NotificationSettingsStore(),
        _notificationScheduler =
            notificationScheduler ?? LocalTeacherNotificationScheduler();

  final TeacherScheduleStore _store;
  final SchoolScheduleStore _schoolScheduleStore;
  final NotificationSettingsStore _notificationSettingsStore;
  final TeacherNotificationScheduler _notificationScheduler;

  List<TeacherClass> _teacherClasses = const <TeacherClass>[];
  SchoolScheduleSettings _schoolSchedule = SchoolScheduleDefaults.settings;
  NotificationSettings _notificationSettings = const NotificationSettings();
  bool _initialized = false;
  bool _notificationBusy = false;
  String _notificationStatus = 'التنبيهات غير مفعلة';

  bool get initialized => _initialized;
  List<TeacherClass> get teacherClasses => List.unmodifiable(_teacherClasses);
  int get activeClassCount => _teacherClasses.where((item) => item.enabled).length;
  SchoolScheduleSettings get schoolSchedule => _schoolSchedule;
  NotificationSettings get notificationSettings => _notificationSettings;
  bool get notificationBusy => _notificationBusy;
  String get notificationStatus => _notificationStatus;

  List<SchoolPeriod> get teacherPeriodCatalog {
    final byId = <String, SchoolPeriod>{};
    for (final profile in _schoolSchedule.profiles.values) {
      for (final period in profile.teachingPeriods) {
        byId.putIfAbsent(period.id, () => period);
      }
    }

    final result = byId.values.toList(growable: false)
      ..sort((a, b) => _periodOrder(a.id).compareTo(_periodOrder(b.id)));
    return List<SchoolPeriod>.unmodifiable(result);
  }

  Future<void> initialize() async {
    _teacherClasses = await _store.load();
    _schoolSchedule = await _schoolScheduleStore.load();
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

  SchoolScheduleProfile? profile(String id) => _schoolSchedule.profiles[id];

  List<SchoolPeriod> teachingPeriodsForWeekday(int weekday) {
    return _schoolSchedule.teachingPeriodsForWeekday(weekday);
  }

  List<SchoolPeriod> teachingPeriodsForDate(DateTime date) {
    return teachingPeriodsForWeekday(date.weekday);
  }

  String effectiveProfileIdForWeekday(int weekday) {
    return _schoolSchedule.effectiveProfileIdForWeekday(weekday);
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
      return _periodOrder(a.periodId).compareTo(_periodOrder(b.periodId));
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

  Future<void> setRamadanMode(bool enabled) async {
    _schoolSchedule = _schoolSchedule.copyWith(ramadanMode: enabled);
    await _persistSchoolSchedule();
  }

  Future<void> setWeekdayProfile(int weekday, String profileId) async {
    final valid = profileId == SchoolScheduleSettings.offProfileId ||
        _schoolSchedule.profiles.containsKey(profileId);
    if (!valid) return;

    _schoolSchedule = _schoolSchedule.copyWith(
      weekdayMap: <int, String>{
        ..._schoolSchedule.weekdayMap,
        weekday: profileId,
      },
    );
    await _persistSchoolSchedule();
  }

  Future<void> updateSchoolPeriod(
    String profileId,
    SchoolPeriod value,
  ) async {
    final profile = _schoolSchedule.profiles[profileId];
    if (profile == null) return;

    final periods = List<SchoolPeriod>.from(profile.periods);
    final index = periods.indexWhere((item) => item.id == value.id);
    if (index < 0) return;

    periods[index] = value;

    final profiles = <String, SchoolScheduleProfile>{
      ..._schoolSchedule.profiles,
      profileId: profile.copyWith(
        periods: List<SchoolPeriod>.unmodifiable(periods),
      ),
    };

    _schoolSchedule = _schoolSchedule.copyWith(profiles: profiles);
    await _persistSchoolSchedule();
  }

  Future<void> resetSchoolSchedule() async {
    _schoolSchedule = SchoolScheduleDefaults.settings;
    await _schoolScheduleStore.clear();
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
      scheduleSettings: _schoolSchedule,
      assignments: _teacherClasses,
    ).evaluate(now);
  }

  Future<void> _persistSchoolSchedule() async {
    await _schoolScheduleStore.save(_schoolSchedule);
    await _syncNotifications();
    notifyListeners();
  }

  Map<int, List<SchoolPeriod>> _notificationPeriodsByWeekday() {
    return <int, List<SchoolPeriod>>{
      for (final weekday in const <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ])
        weekday: _schoolSchedule.teachingPeriodsForWeekday(weekday),
    };
  }

  Future<void> _syncNotifications() async {
    if (!_notificationSettings.enabled) return;

    await _notificationScheduler.sync(
      assignments: _teacherClasses,
      periodsByWeekday: _notificationPeriodsByWeekday(),
      settings: _notificationSettings,
    );
  }

  static int _periodOrder(String periodId) {
    return int.tryParse(periodId.replaceAll(RegExp(r'\D'), '')) ?? 99;
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
