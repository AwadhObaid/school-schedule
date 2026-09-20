import 'package:flutter/foundation.dart';

import 'app_info.dart';
import 'data/school_schedule_defaults.dart';
import 'models/app_appearance.dart';
import 'models/app_backup.dart';
import 'models/bell_settings.dart';
import 'models/notification_settings.dart';
import 'models/school_notification_settings.dart';
import 'models/school_period.dart';
import 'models/school_schedule_settings.dart';
import 'models/teacher_class.dart';
import 'services/app_share_service.dart';
import 'services/backup_file_service.dart';
import 'services/bell_audio_service.dart';
import 'services/legacy_backup_migration.dart';
import 'services/school_bell_engine.dart';
import 'services/school_day_engine.dart';
import 'services/teacher_notification_scheduler.dart';
import 'services/teacher_schedule_engine.dart';
import 'storage/appearance_store.dart';
import 'storage/bell_settings_store.dart';
import 'storage/pin_store.dart';
import 'storage/notification_settings_store.dart';
import 'storage/school_notification_settings_store.dart';
import 'storage/school_schedule_store.dart';
import 'storage/teacher_schedule_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    TeacherScheduleStore? store,
    SchoolScheduleStore? schoolScheduleStore,
    NotificationSettingsStore? notificationSettingsStore,
    SchoolNotificationSettingsStore? schoolNotificationSettingsStore,
    BellSettingsStore? bellSettingsStore,
    PinStore? pinStore,
    AppearanceStore? appearanceStore,
    BackupFileService? backupFileService,
    AppShareService? appShareService,
    TeacherNotificationScheduler? notificationScheduler,
    BellAudioService? bellAudioService,
    SchoolBellEngine? schoolBellEngine,
  })  : _store = store ?? TeacherScheduleStore(),
        _schoolScheduleStore = schoolScheduleStore ?? SchoolScheduleStore(),
        _notificationSettingsStore =
            notificationSettingsStore ?? NotificationSettingsStore(),
        _schoolNotificationSettingsStore =
            schoolNotificationSettingsStore ??
                SchoolNotificationSettingsStore(),
        _bellSettingsStore = bellSettingsStore ?? BellSettingsStore(),
        _pinStore = pinStore ?? PinStore(),
        _appearanceStore = appearanceStore ?? AppearanceStore(),
        _backupFileService = backupFileService ?? MethodChannelBackupFileService(),
        _appShareService = appShareService ?? MethodChannelAppShareService(),
        _notificationScheduler =
            notificationScheduler ?? LocalTeacherNotificationScheduler(),
        _bellAudioService =
            bellAudioService ?? MethodChannelBellAudioService(),
        _schoolBellEngine = schoolBellEngine ?? const SchoolBellEngine();

  final TeacherScheduleStore _store;
  final SchoolScheduleStore _schoolScheduleStore;
  final NotificationSettingsStore _notificationSettingsStore;
  final SchoolNotificationSettingsStore _schoolNotificationSettingsStore;
  final BellSettingsStore _bellSettingsStore;
  final PinStore _pinStore;
  final AppearanceStore _appearanceStore;
  final BackupFileService _backupFileService;
  final AppShareService _appShareService;
  final TeacherNotificationScheduler _notificationScheduler;
  final BellAudioService _bellAudioService;
  final SchoolBellEngine _schoolBellEngine;

  List<TeacherClass> _teacherClasses = const <TeacherClass>[];
  SchoolScheduleSettings _schoolSchedule = SchoolScheduleDefaults.settings;
  NotificationSettings _notificationSettings = const NotificationSettings();
  SchoolNotificationSettings _schoolNotificationSettings =
      const SchoolNotificationSettings();
  BellSettings _bellSettings = const BellSettings();
  AppAppearance _appearance = AppAppearance.light;
  String _settingsPin = PinStore.defaultPin;

  bool _initialized = false;
  bool _notificationBusy = false;
  bool _schoolNotificationBusy = false;
  bool _bellBusy = false;
  bool _backupBusy = false;
  String _notificationStatus = 'التنبيهات غير مفعلة';
  String _schoolNotificationStatus = 'تنبيهات الجدول المدرسي غير مفعلة';
  String _bellStatus = 'صوت الجرس غير مفعل';
  String _backupStatus = 'لم يتم إنشاء نسخة احتياطية في هذه الجلسة';
  String? _bellNotificationChannelId;

  bool get initialized => _initialized;
  List<TeacherClass> get teacherClasses => List.unmodifiable(_teacherClasses);
  int get activeClassCount =>
      _teacherClasses.where((item) => item.enabled).length;
  SchoolScheduleSettings get schoolSchedule => _schoolSchedule;
  NotificationSettings get notificationSettings => _notificationSettings;
  SchoolNotificationSettings get schoolNotificationSettings =>
      _schoolNotificationSettings;
  BellSettings get bellSettings => _bellSettings;
  AppAppearance get appearance => _appearance;
  bool get notificationBusy => _notificationBusy;
  bool get schoolNotificationBusy => _schoolNotificationBusy;
  bool get bellBusy => _bellBusy;
  bool get backupBusy => _backupBusy;
  String get notificationStatus => _notificationStatus;
  String get schoolNotificationStatus => _schoolNotificationStatus;
  String get bellStatus => _bellStatus;
  String get backupStatus => _backupStatus;

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
    _schoolNotificationSettings =
        await _schoolNotificationSettingsStore.load();
    _bellSettings = await _bellSettingsStore.load();
    _appearance = await _appearanceStore.load();
    _settingsPin = await _pinStore.load();

    await _notificationScheduler.initialize();
    await _configureBellChannel();

    _bellStatus = _bellSettings.enabled
        ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
        : 'صوت الجرس غير مفعل';

    if (_notificationSettings.enabled) {
      _notificationStatus = 'تنبيهات حصصي مفعلة';
    }
    if (_schoolNotificationSettings.enabled) {
      _schoolNotificationStatus = 'تنبيهات الجدول المدرسي مفعلة';
    }
    if (_notificationSettings.enabled || _schoolNotificationSettings.enabled) {
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

  bool isBuiltInProfile(String profileId) {
    return profileId == SchoolScheduleSettings.normalProfileId ||
        profileId == SchoolScheduleSettings.ramadanProfileId;
  }

  Future<String> createScheduleProfile({
    required String name,
    String? sourceProfileId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Schedule name cannot be empty.');
    }

    var suffix = DateTime.now().millisecondsSinceEpoch;
    var id = 'custom_$suffix';
    while (_schoolSchedule.profiles.containsKey(id)) {
      suffix += 1;
      id = 'custom_$suffix';
    }

    final source = sourceProfileId == null
        ? null
        : _schoolSchedule.profiles[sourceProfileId];

    final profile = SchoolScheduleProfile(
      id: id,
      name: cleanName,
      periods: List<SchoolPeriod>.unmodifiable(
        source == null ? const <SchoolPeriod>[] : List.of(source.periods),
      ),
    );

    _schoolSchedule = _schoolSchedule.copyWith(
      profiles: <String, SchoolScheduleProfile>{
        ..._schoolSchedule.profiles,
        id: profile,
      },
    );

    await _persistSchoolSchedule();
    return id;
  }

  Future<bool> renameScheduleProfile(
    String profileId,
    String name,
  ) async {
    final profile = _schoolSchedule.profiles[profileId];
    final cleanName = name.trim();

    if (profile == null || cleanName.isEmpty || isBuiltInProfile(profileId)) {
      return false;
    }

    _schoolSchedule = _schoolSchedule.copyWith(
      profiles: <String, SchoolScheduleProfile>{
        ..._schoolSchedule.profiles,
        profileId: profile.copyWith(name: cleanName),
      },
    );

    await _persistSchoolSchedule();
    return true;
  }

  Future<bool> deleteScheduleProfile(String profileId) async {
    if (isBuiltInProfile(profileId) ||
        !_schoolSchedule.profiles.containsKey(profileId)) {
      return false;
    }

    final profiles = <String, SchoolScheduleProfile>{
      ..._schoolSchedule.profiles,
    }..remove(profileId);

    final weekdayMap = <int, String>{
      for (final entry in _schoolSchedule.weekdayMap.entries)
        entry.key: entry.value == profileId
            ? SchoolScheduleSettings.offProfileId
            : entry.value,
    };

    _schoolSchedule = _schoolSchedule.copyWith(
      profiles: profiles,
      weekdayMap: weekdayMap,
    );

    await _persistSchoolSchedule();
    return true;
  }

  Future<SchoolPeriod?> addSchoolPeriod(String profileId) async {
    final profile = _schoolSchedule.profiles[profileId];
    if (profile == null) return null;

    final periods = List<SchoolPeriod>.from(profile.periods);
    final nextNumber = _nextTeacherPeriodNumber(profileId);
    final lastEnd = periods.isEmpty
        ? 8 * 60
        : periods.map((item) => item.endMinutes).reduce(
              (left, right) => left > right ? left : right,
            );

    if (lastEnd + 35 > 24 * 60) return null;

    final value = SchoolPeriod(
      id: 'p$nextNumber',
      name: 'الحصة $nextNumber',
      startMinutes: lastEnd,
      durationMinutes: 35,
    );

    periods.add(value);
    periods.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    _schoolSchedule = _schoolSchedule.copyWith(
      profiles: <String, SchoolScheduleProfile>{
        ..._schoolSchedule.profiles,
        profileId: profile.copyWith(
          periods: List<SchoolPeriod>.unmodifiable(periods),
        ),
      },
    );

    await _persistSchoolSchedule();
    return value;
  }

  Future<bool> removeSchoolPeriod(
    String profileId,
    String periodId,
  ) async {
    final profile = _schoolSchedule.profiles[profileId];
    if (profile == null) return false;

    final periods = profile.periods
        .where((item) => item.id != periodId)
        .toList(growable: false);

    if (periods.length == profile.periods.length) return false;

    _schoolSchedule = _schoolSchedule.copyWith(
      profiles: <String, SchoolScheduleProfile>{
        ..._schoolSchedule.profiles,
        profileId: profile.copyWith(
          periods: List<SchoolPeriod>.unmodifiable(periods),
        ),
      },
    );

    await _persistSchoolSchedule();
    return true;
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

  Future<bool> updateSchoolPeriod(
    String profileId,
    SchoolPeriod value,
  ) async {
    final profile = _schoolSchedule.profiles[profileId];
    if (profile == null) return false;

    final periods = List<SchoolPeriod>.from(profile.periods);
    final index = periods.indexWhere((item) => item.id == value.id);
    if (index < 0) return false;

    periods[index] = value;
    periods.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    if (!_periodsAreValid(periods)) return false;

    final profiles = <String, SchoolScheduleProfile>{
      ..._schoolSchedule.profiles,
      profileId: profile.copyWith(
        periods: List<SchoolPeriod>.unmodifiable(periods),
      ),
    };

    _schoolSchedule = _schoolSchedule.copyWith(profiles: profiles);
    await _persistSchoolSchedule();
    return true;
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

  bool verifySettingsPin(String value) => value == _settingsPin;

  Future<bool> changeSettingsPin(String value) async {
    final pin = value.trim();
    if (!PinStore.isValid(pin)) return false;
    _settingsPin = pin;
    await _pinStore.save(pin);
    notifyListeners();
    return true;
  }

  Future<bool> exportBackup() async {
    if (_backupBusy) return false;
    _backupBusy = true;
    _backupStatus = 'جارٍ تجهيز النسخة الاحتياطية...';
    notifyListeners();

    try {
      BellRingtoneBackup? ringtone;
      if (!_bellSettings.usesSystemRingtone) {
        ringtone = await _bellAudioService.exportRingtone();
      }

      final backup = AppBackup(
        appVersion: AppInfo.version,
        exportedAt: DateTime.now(),
        pin: _settingsPin,
        schoolSchedule: _schoolSchedule,
        teacherClasses: _teacherClasses,
        notificationSettings: _notificationSettings,
        schoolNotificationSettings: _schoolNotificationSettings,
        bellSettings: _bellSettings,
        appearance: _appearance,
        ringtoneName: ringtone?.name,
        ringtoneBase64: ringtone?.base64,
      );

      final date = DateTime.now().toIso8601String().split('T').first;
      final shared = await _backupFileService.shareBackup(
        fileName: 'school-schedule-v2-backup-$date.json',
        json: backup.encode(),
      );

      _backupStatus = shared
          ? 'تم تجهيز النسخة الاحتياطية. اختر مكان حفظها أو مشاركتها.'
          : 'تعذر فتح نافذة حفظ النسخة الاحتياطية.';
      return shared;
    } finally {
      _backupBusy = false;
      notifyListeners();
    }
  }

  Future<BackupParseResult?> pickBackup() async {
    if (_backupBusy) return null;
    _backupBusy = true;
    _backupStatus = 'جارٍ قراءة النسخة الاحتياطية...';
    notifyListeners();

    try {
      final text = await _backupFileService.pickBackup();
      if (text == null || text.trim().isEmpty) {
        _backupStatus = 'لم يتم اختيار ملف.';
        return null;
      }

      final result = AppBackup.parse(text);
      _backupStatus = result.isValid
          ? 'تم التحقق من النسخة الاحتياطية بنجاح.'
          : (result.error ?? 'النسخة الاحتياطية غير صالحة.');
      return result;
    } finally {
      _backupBusy = false;
      notifyListeners();
    }
  }

  Future<bool> applyBackup(AppBackup backup) async {
    if (_backupBusy) return false;
    _backupBusy = true;
    _backupStatus = 'جارٍ استعادة البيانات...';
    notifyListeners();

    try {
      var restoredBell = backup.bellSettings;

      if (backup.includesCustomRingtone) {
        final selection = await _bellAudioService.restoreRingtone(
          name: backup.ringtoneName ?? backup.bellSettings.ringtoneName,
          base64: backup.ringtoneBase64!,
        );

        if (selection != null) {
          restoredBell = restoredBell.copyWith(
            ringtoneUri: selection.uri,
            ringtoneName: selection.name,
          );
        } else {
          restoredBell = restoredBell.copyWith(
            ringtoneUri: '',
            ringtoneName: 'نغمة النظام',
          );
        }
      } else if (!backup.bellSettings.usesSystemRingtone) {
        restoredBell = restoredBell.copyWith(
          ringtoneUri: '',
          ringtoneName: 'نغمة النظام',
        );
      }

      _schoolSchedule = backup.schoolSchedule;
      _teacherClasses = List<TeacherClass>.unmodifiable(backup.teacherClasses);
      _notificationSettings = backup.notificationSettings;
      _schoolNotificationSettings = backup.schoolNotificationSettings;
      _bellSettings = restoredBell;
      _appearance = backup.appearance;
      _settingsPin = backup.pin;

      await _schoolScheduleStore.save(_schoolSchedule);
      await _store.save(_teacherClasses);
      await _notificationSettingsStore.save(_notificationSettings);
      await _schoolNotificationSettingsStore.save(
        _schoolNotificationSettings,
      );
      await _bellSettingsStore.save(_bellSettings);
      await _appearanceStore.save(_appearance);
      await _pinStore.save(_settingsPin);

      await _configureBellChannel();

      await _syncNotifications();

      _bellStatus = _bellSettings.enabled
          ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
          : 'صوت الجرس غير مفعل';
      _notificationStatus = _notificationSettings.enabled
          ? 'تنبيهات حصصي مفعلة'
          : 'التنبيهات غير مفعلة';
      _schoolNotificationStatus = _schoolNotificationSettings.enabled
          ? 'تنبيهات الجدول المدرسي مفعلة'
          : 'تنبيهات الجدول المدرسي غير مفعلة';
      _backupStatus = 'تمت استعادة النسخة الاحتياطية بنجاح.';
      return true;
    } finally {
      _backupBusy = false;
      notifyListeners();
    }
  }

  Future<void> setAppearance(AppAppearance value) async {
    if (_appearance == value) return;
    _appearance = value;
    await _appearanceStore.save(value);
    notifyListeners();
  }

  Future<bool> shareApplication() async {
    return _appShareService.shareText(AppInfo.shareText);
  }

  Future<LegacyMigrationParseResult?> pickLegacyBackup() async {
    if (_backupBusy) return null;

    _backupBusy = true;
    _backupStatus = 'جارٍ قراءة نسخة التطبيق القديم...';
    notifyListeners();

    try {
      final text = await _backupFileService.pickBackup();

      if (text == null || text.trim().isEmpty) {
        _backupStatus = 'لم يتم اختيار ملف.';
        return null;
      }

      final result = LegacyBackupMigration.parse(text);
      _backupStatus = result.isValid
          ? 'تم التحقق من نسخة التطبيق القديم بنجاح.'
          : (result.error ?? 'نسخة التطبيق القديم غير صالحة.');
      return result;
    } finally {
      _backupBusy = false;
      notifyListeners();
    }
  }

  Future<bool> applyLegacyMigration(LegacyMigrationData data) async {
    if (_backupBusy) return false;

    _backupBusy = true;
    _backupStatus = 'جارٍ ترحيل بيانات التطبيق القديم...';
    notifyListeners();

    try {
      if (data.hadCustomRingtone) {
        await _bellAudioService.stopPreview();
        await _bellAudioService.resetRingtone();
      }

      _schoolSchedule = data.schoolSchedule;
      _schoolNotificationSettings = data.schoolNotificationSettings;
      _bellSettings = data.bellSettings;
      _settingsPin = data.pin;

      await _schoolScheduleStore.save(_schoolSchedule);
      await _schoolNotificationSettingsStore.save(
        _schoolNotificationSettings,
      );
      await _bellSettingsStore.save(_bellSettings);
      await _pinStore.save(_settingsPin);

      await _configureBellChannel();

      await _syncNotifications();

      _bellStatus = _bellSettings.enabled
          ? 'صوت الجرس مفعل • ${_bellSettings.ringtoneName}'
          : 'صوت الجرس غير مفعل';
      _notificationStatus = _notificationSettings.enabled
          ? 'تنبيهات حصصي مفعلة'
          : 'التنبيهات غير مفعلة';
      _schoolNotificationStatus = _schoolNotificationSettings.enabled
          ? 'تنبيهات الجدول المدرسي مفعلة'
          : 'تنبيهات الجدول المدرسي غير مفعلة';

      _backupStatus =
          'تم ترحيل بيانات التطبيق القديم. حصص Flutter وتنبيهاتها الشخصية بقيت محفوظة.';
      return true;
    } finally {
      _backupBusy = false;
      notifyListeners();
    }
  }

  Future<bool> setSchoolNotificationSettings(
    SchoolNotificationSettings value,
  ) async {
    if (_schoolNotificationBusy) return false;

    _schoolNotificationBusy = true;
    notifyListeners();

    try {
      var next = value;

      if (value.enabled && !_schoolNotificationSettings.enabled) {
        final permissions = await _notificationScheduler.requestPermissions();

        if (!permissions.notificationsGranted) {
          next = value.copyWith(enabled: false);
          _schoolNotificationStatus =
              'لم يتم منح إذن الإشعارات. يمكنك المحاولة مرة أخرى من الإعدادات.';
          _schoolNotificationSettings = next;
          await _schoolNotificationSettingsStore.save(next);
          await _notificationScheduler.cancelSchoolScheduleNotifications();
          return false;
        }

        _schoolNotificationStatus = permissions.exactAlarmsGranted
            ? 'تنبيهات الجدول الدقيقة مفعلة'
            : 'تنبيهات الجدول مفعلة بوضع تقريبي لأن إذن التنبيه الدقيق غير متاح';
      } else if (!value.enabled) {
        _schoolNotificationStatus = 'تنبيهات الجدول المدرسي غير مفعلة';
      } else {
        _schoolNotificationStatus = 'تنبيهات الجدول المدرسي مفعلة';
      }

      _schoolNotificationSettings = next;
      await _schoolNotificationSettingsStore.save(next);

      if (next.enabled) {
        await _notificationScheduler.syncSchoolSchedule(
          schedule: _schoolSchedule,
          enabled: true,
          androidChannelId: _bellNotificationChannelId,
        );
      } else {
        await _notificationScheduler.cancelSchoolScheduleNotifications();
      }

      return next.enabled == value.enabled;
    } finally {
      _schoolNotificationBusy = false;
      notifyListeners();
    }
  }

  Future<void> showSchoolScheduleTestNotification() async {
    if (!_schoolNotificationSettings.enabled || _schoolNotificationBusy) return;

    await _notificationScheduler.showSchoolScheduleTestNotification(
      androidChannelId: _bellNotificationChannelId,
    );
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

  SchoolDayStatus schoolDayStatusAt(DateTime now) {
    return SchoolDayEngine(
      scheduleSettings: _schoolSchedule,
    ).evaluate(now);
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
    if (_notificationSettings.enabled) {
      await _notificationScheduler.sync(
        assignments: _teacherClasses,
        periodsByWeekday: _notificationPeriodsByWeekday(),
        settings: _notificationSettings,
        androidChannelId: _bellNotificationChannelId,
      );
    } else {
      await _notificationScheduler.cancelTeacherNotifications();
    }

    if (_schoolNotificationSettings.enabled) {
      await _notificationScheduler.syncSchoolSchedule(
        schedule: _schoolSchedule,
        enabled: true,
        androidChannelId: _bellNotificationChannelId,
      );
    } else {
      await _notificationScheduler.cancelSchoolScheduleNotifications();
    }
  }

  int _nextTeacherPeriodNumber(String profileId) {
    final profile = _schoolSchedule.profiles[profileId];
    if (profile == null) return 1;

    final used = <int>{};
    for (final period in profile.teachingPeriods) {
      final digits = period.id.replaceAll(RegExp('[^0-9]'), '');
      final number = int.tryParse(digits) ?? 0;
      if (number > 0) used.add(number);
    }

    var candidate = 1;
    while (used.contains(candidate)) {
      candidate += 1;
    }
    return candidate;
  }

  bool _periodsAreValid(List<SchoolPeriod> periods) {
    if (periods.isEmpty) return true;

    SchoolPeriod? previous;
    for (final period in periods) {
      if (period.startMinutes < 0 ||
          period.startMinutes >= 24 * 60 ||
          period.durationMinutes <= 0 ||
          period.durationMinutes > 600 ||
          period.endMinutes > 24 * 60) {
        return false;
      }

      if (previous != null && period.startMinutes < previous.endMinutes) {
        return false;
      }
      previous = period;
    }

    return true;
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
