import 'package:flutter/foundation.dart';

import 'data/school_schedule_defaults.dart';
import 'models/bell_settings.dart';
import 'models/notification_settings.dart';
import 'models/school_period.dart';
import 'models/school_schedule_settings.dart';
import 'models/teacher_class.dart';
import 'services/bell_audio_service.dart';
import 'services/school_bell_engine.dart';
import 'services/teacher_notification_scheduler.dart';
import 'services/teacher_schedule_engine.dart';
import 'storage/bell_settings_store.dart';
import 'storage/notification_settings_store.dart';
import 'storage/school_schedule_store.dart';
import 'storage/teacher_schedule_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    TeacherScheduleStore? store,
    SchoolScheduleStore? schoolScheduleStore,
    NotificationSettingsStore? notificationSettingsStore,
    BellSettingsStore? bellSettingsStore,
    TeacherNotificationScheduler? notificationScheduler,
    BellAudioService? bellAudioService,
    SchoolBellEngine? schoolBellEngine,
  })  : _store = store ?? TeacherScheduleStore(),
        _schoolScheduleStore = schoolScheduleStore ?? SchoolScheduleStore(),
        _notificationSettingsStore =
            notificationSettingsStore ?? NotificationSettingsStore(),
        _bellSettingsStore = bellSettingsStore ?? BellSettingsStore(),
        _notificationScheduler =
            notificationScheduler ?? LocalTeacherNotificationScheduler(),
        _bellAudioService =
            bellAudioService ?? MethodChannelBellAudioService(),
        _schoolBellEngine = schoolBellEngine ?? const SchoolBellEngine();

  final TeacherScheduleStore _store;
  final SchoolScheduleStore _schoolScheduleStore;
  final NotificationSettingsStore _notificationSettingsStore;
  final BellSettingsStore _bellSettingsStore;
  final TeacherNotificationScheduler _notificationScheduler;
  final BellAudioService _bellAudioService;
  final SchoolBellEngine _schoolBellEngine;

  List<TeacherClass> _teacherClasses = const <TeacherClass>[];
  SchoolScheduleSettings _schoolSchedule = SchoolScheduleDefaults.settings;
  NotificationSettings _notificationSettings = const NotificationSettings();
  BellSettings _bellSettings = const BellSettings();

  bool _initialized = false;
  bool _notificationBusy = false;
  bool _bellBusy = false;
  String _notificationStatus = 'التنبيهات غير مفعلة';
  String _bellStatus = 'صوت الجرس غير مفعل';
  String? _bellNotificationChannelId;

  bool get initialized => _initialized;
  List<TeacherClass> get teacherClasses => List.unmodifiable(_teacherClasses);
  int get activeClassCount =>
      _teacherClasses.where((item) => item.enabled).length;
  SchoolScheduleSettings get schoolSchedule => _schoolSchedule;
  NotificationSettings get notificationSettings => _notificationSettings;
  BellSettings get bellSettings => _bellSettings;
  bool get notificationBusy => _notificationBusy;
  bool get bellBusy => _bellBusy;
  String get notificationStatus => _notificationStatus;
  String get bellStatus => _bellStatus;

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
    _bellSettings = await _bellSettingsStore.load();

    await _notificationScheduler.initialize();
    await _configureBellChannel();

    _bellStatus = _bellSettings.enabled
        ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
        : 'صوت الجرس غير مفعل';

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

  String schoolBellStateKeyAt(DateTime now) {
    return _schoolBellEngine.stateKeyAt(
      schedule: _schoolSchedule,
      now: now,
    );
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

  Future<void> setBellEnabled(bool enabled) async {
    if (_bellBusy) return;

    _bellSettings = _bellSettings.copyWith(enabled: enabled);
    await _bellSettingsStore.save(_bellSettings);

    _bellStatus = enabled
        ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
        : 'صوت الجرس غير مفعل';

    notifyListeners();

    if (enabled) {
      await _bellAudioService.playPreview(_bellSettings);
    } else {
      await _bellAudioService.stopPreview();
    }
  }

  Future<bool> pickBellRingtone() async {
    if (_bellBusy) return false;

    _bellBusy = true;
    _bellStatus = 'اختر ملفًا صوتيًا من الجهاز';
    notifyListeners();

    try {
      final selected = await _bellAudioService.pickRingtone();
      if (selected == null) {
        _bellStatus = _bellSettings.enabled
            ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
            : 'لم يتم تغيير النغمة';
        return false;
      }

      _bellSettings = _bellSettings.copyWith(
        ringtoneUri: selected.uri,
        ringtoneName: selected.name,
      );
      await _bellSettingsStore.save(_bellSettings);
      await _configureBellChannel();
      await _syncNotifications();

      _bellStatus = 'تم اختيار: ${selected.name}';
      return true;
    } finally {
      _bellBusy = false;
      notifyListeners();
    }
  }

  Future<void> resetBellRingtone() async {
    if (_bellBusy) return;

    _bellBusy = true;
    notifyListeners();

    try {
      await _bellAudioService.stopPreview();
      await _bellAudioService.resetRingtone();

      _bellSettings = _bellSettings.copyWith(
        ringtoneUri: '',
        ringtoneName: 'نغمة النظام',
      );
      await _bellSettingsStore.save(_bellSettings);
      await _configureBellChannel();
      await _syncNotifications();

      _bellStatus = _bellSettings.enabled
          ? 'صوت الجرس مفعل • نغمة النظام'
          : 'تمت استعادة نغمة النظام';
    } finally {
      _bellBusy = false;
      notifyListeners();
    }
  }

  Future<void> setBellVolume(int volume) async {
    final normalized = volume.clamp(0, 100).toInt();
    if (_bellSettings.volume == normalized) return;

    _bellSettings = _bellSettings.copyWith(volume: normalized);
    await _bellSettingsStore.save(_bellSettings);
    await _configureBellChannel();
    notifyListeners();
  }

  Future<void> previewBell() async {
    if (_bellBusy) return;
    await _bellAudioService.playPreview(_bellSettings);
  }

  Future<void> playAutomaticSchoolBell() async {
    if (!_bellSettings.enabled || _bellBusy) return;
    await _bellAudioService.playPreview(_bellSettings);
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
    await _notificationScheduler.showTestNotification(
      androidChannelId: _bellNotificationChannelId,
    );
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

  Future<void> _configureBellChannel() async {
    final channelId = await _bellAudioService.configure(_bellSettings);
    if (channelId != null && channelId.trim().isNotEmpty) {
      _bellNotificationChannelId = channelId.trim();
    }
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
      androidChannelId: _bellNotificationChannelId,
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
