import 'dart:convert';

import '../data/school_schedule_defaults.dart';
import '../models/bell_settings.dart';
import '../models/notification_settings.dart';
import '../models/school_period.dart';
import '../models/school_schedule_settings.dart';

class LegacyMigrationData {
  const LegacyMigrationData({
    required this.schoolSchedule,
    required this.notificationSettings,
    required this.bellSettings,
    required this.pin,
    required this.sourceVersion,
    required this.scheduleCount,
    required this.hadCustomRingtone,
    required this.warnings,
  });

  final SchoolScheduleSettings schoolSchedule;
  final NotificationSettings notificationSettings;
  final BellSettings bellSettings;
  final String pin;
  final String sourceVersion;
  final int scheduleCount;
  final bool hadCustomRingtone;
  final List<String> warnings;
}

class LegacyMigrationParseResult {
  const LegacyMigrationParseResult.success(this.data)
      : error = null;

  const LegacyMigrationParseResult.failure(this.error)
      : data = null;

  final LegacyMigrationData? data;
  final String? error;

  bool get isValid => data != null && error == null;
}

abstract final class LegacyBackupMigration {
  static const legacyFormat = 'school-schedule-backup';
  static const maxSupportedBackupVersion = 1;

  static LegacyMigrationParseResult parse(String text) {
    dynamic decoded;

    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const LegacyMigrationParseResult.failure(
        'الملف ليس JSON صالحًا.',
      );
    }

    if (decoded is! Map) {
      return const LegacyMigrationParseResult.failure(
        'بنية ملف النسخة القديمة غير صالحة.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);
    Map<String, dynamic> state;

    if (root.containsKey('format')) {
      if (root['format']?.toString() != legacyFormat) {
        return const LegacyMigrationParseResult.failure(
          'هذا الملف ليس نسخة احتياطية من تطبيق التوقيت المدرسي القديم.',
        );
      }

      final version =
          int.tryParse(root['backupVersion']?.toString() ?? '') ?? 0;
      if (version > maxSupportedBackupVersion) {
        return const LegacyMigrationParseResult.failure(
          'النسخة القديمة أُنشئت بتنسيق أحدث من التنسيق المدعوم.',
        );
      }

      final rawState = root['state'];
      if (rawState is! Map) {
        return const LegacyMigrationParseResult.failure(
          'بيانات الحالة غير موجودة داخل النسخة القديمة.',
        );
      }
      state = Map<String, dynamic>.from(rawState);
    } else {
      state = root;
    }

    final pin = state['pin']?.toString().trim() ?? '';
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      return const LegacyMigrationParseResult.failure(
        'رمز الدخول في النسخة القديمة غير صالح.',
      );
    }

    final rawSchedules = state['schedules'];
    if (rawSchedules is! Map || rawSchedules.isEmpty) {
      return const LegacyMigrationParseResult.failure(
        'النسخة القديمة لا تحتوي على جداول صالحة.',
      );
    }

    final profiles = <String, SchoolScheduleProfile>{};

    try {
      for (final entry in rawSchedules.entries) {
        final id = entry.key.toString().trim();
        if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
          return LegacyMigrationParseResult.failure(
            'معرّف الجدول القديم "$id" غير صالح.',
          );
        }

        if (entry.value is! Map) {
          return LegacyMigrationParseResult.failure(
            'بيانات الجدول "$id" غير صالحة.',
          );
        }

        final schedule = Map<String, dynamic>.from(entry.value as Map);
        final name = schedule['name']?.toString().trim() ?? '';
        final rawPeriods = schedule['periods'];

        if (name.isEmpty || rawPeriods is! List || rawPeriods.isEmpty) {
          return LegacyMigrationParseResult.failure(
            'الجدول "$id" ناقص أو لا يحتوي على فترات.',
          );
        }

        final temporary = <_LegacyPeriod>[];

        for (var index = 0; index < rawPeriods.length; index += 1) {
          final raw = rawPeriods[index];
          if (raw is! Map) {
            return LegacyMigrationParseResult.failure(
              'يوجد سجل فترة غير صالح داخل "$name".',
            );
          }

          final period = Map<String, dynamic>.from(raw);
          final periodName = period['name']?.toString().trim() ?? '';
          final start = period['start']?.toString().trim() ?? '';
          final duration =
              int.tryParse(period['duration']?.toString() ?? '') ?? 0;
          final startMinutes = _timeToMinutes(start);

          if (periodName.isEmpty ||
              startMinutes == null ||
              duration < 1 ||
              duration > 600 ||
              startMinutes + duration > 24 * 60) {
            return LegacyMigrationParseResult.failure(
              'يوجد وقت أو مدة غير صالحة داخل جدول "$name".',
            );
          }

          temporary.add(
            _LegacyPeriod(
              name: periodName,
              startMinutes: startMinutes,
              durationMinutes: duration,
            ),
          );
        }

        temporary.sort(
          (a, b) => a.startMinutes.compareTo(b.startMinutes),
        );

        for (var index = 1; index < temporary.length; index += 1) {
          if (temporary[index].startMinutes <
              temporary[index - 1].endMinutes) {
            return LegacyMigrationParseResult.failure(
              'يوجد تداخل بين فترات جدول "$name".',
            );
          }
        }

        var teachingNumber = 0;
        var specialNumber = 0;
        var assemblyUsed = false;
        var breakUsed = false;
        final periods = <SchoolPeriod>[];

        for (final period in temporary) {
          final special = _specialKind(period.name);
          String periodId;
          var selectable = true;

          if (special == _SpecialPeriod.assembly && !assemblyUsed) {
            periodId = 'assembly';
            assemblyUsed = true;
            selectable = false;
          } else if (special == _SpecialPeriod.breakTime && !breakUsed) {
            periodId = 'break';
            breakUsed = true;
            selectable = false;
          } else if (special != _SpecialPeriod.none) {
            specialNumber += 1;
            periodId = 'legacy_non_teaching_$specialNumber';
            selectable = false;
          } else {
            teachingNumber += 1;
            periodId = 'p$teachingNumber';
          }

          periods.add(
            SchoolPeriod(
              id: periodId,
              name: period.name,
              startMinutes: period.startMinutes,
              durationMinutes: period.durationMinutes,
              teacherSelectable: selectable,
            ),
          );
        }

        profiles[id] = SchoolScheduleProfile(
          id: id,
          name: name,
          periods: List<SchoolPeriod>.unmodifiable(periods),
        );
      }
    } catch (_) {
      return const LegacyMigrationParseResult.failure(
        'تعذر تحويل جداول النسخة القديمة.',
      );
    }

    const defaults = SchoolScheduleDefaults.settings;
    profiles.putIfAbsent(
      SchoolScheduleSettings.normalProfileId,
      () => defaults.profiles[SchoolScheduleSettings.normalProfileId]!,
    );
    profiles.putIfAbsent(
      SchoolScheduleSettings.ramadanProfileId,
      () => defaults.profiles[SchoolScheduleSettings.ramadanProfileId]!,
    );

    final weekdayMap = <int, String>{};
    final rawWeekdayMap = state['weekdayMap'];

    for (var legacyDay = 0; legacyDay < 7; legacyDay += 1) {
      final selected = rawWeekdayMap is Map
          ? rawWeekdayMap[legacyDay]?.toString() ??
              rawWeekdayMap[legacyDay.toString()]?.toString() ??
              SchoolScheduleSettings.offProfileId
          : SchoolScheduleSettings.offProfileId;

      final dartWeekday = _legacyDayToDartWeekday(legacyDay);
      weekdayMap[dartWeekday] =
          selected == SchoolScheduleSettings.offProfileId ||
                  profiles.containsKey(selected)
              ? selected
              : SchoolScheduleSettings.offProfileId;
    }

    final ringtoneUri = state['ringtoneUri']?.toString().trim() ?? '';
    final ringtoneName = state['ringtoneName']?.toString().trim() ?? '';
    final hadCustomRingtone = ringtoneUri.isNotEmpty;

    final warnings = <String>[
      'حصصي الشخصية غير موجودة في التطبيق القديم، لذلك ستبقى حصص Flutter الحالية كما هي.',
      if (hadCustomRingtone)
        'النسخة القديمة تحفظ رابط النغمة فقط ولا تحفظ الملف الصوتي؛ ستُستخدم نغمة النظام حتى تعيد اختيار النغمة من الجهاز.',
    ];

    return LegacyMigrationParseResult.success(
      LegacyMigrationData(
        schoolSchedule: SchoolScheduleSettings(
          ramadanMode: state['ramadanMode'] is bool
              ? state['ramadanMode'] as bool
              : false,
          weekdayMap: weekdayMap,
          profiles: profiles,
        ),
        notificationSettings: NotificationSettings(
          enabled: state['notificationsEnabled'] is bool
              ? state['notificationsEnabled'] as bool
              : (state['soundEnabled'] is bool
                  ? state['soundEnabled'] as bool
                  : false),
          preAlertMinutes: 0,
          startAlert: true,
          endAlert: true,
        ),
        bellSettings: BellSettings(
          enabled: state['soundEnabled'] is bool
              ? state['soundEnabled'] as bool
              : false,
          ringtoneUri: '',
          ringtoneName:
              hadCustomRingtone || ringtoneName.isEmpty
                  ? 'نغمة النظام'
                  : ringtoneName,
          volume: (int.tryParse(state['bellVolume']?.toString() ?? '') ?? 80)
              .clamp(0, 100)
              .toInt(),
        ),
        pin: pin,
        sourceVersion: root['appVersion']?.toString() ?? 'غير معروف',
        scheduleCount: rawSchedules.length,
        hadCustomRingtone: hadCustomRingtone,
        warnings: List<String>.unmodifiable(warnings),
      ),
    );
  }

  static int? _timeToMinutes(String value) {
    final match =
        RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
    if (match == null) return null;

    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static int _legacyDayToDartWeekday(int value) {
    return value == 0 ? DateTime.sunday : value;
  }

  static _SpecialPeriod _specialKind(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('طابور')) return _SpecialPeriod.assembly;
    if (normalized.contains('فسحة') ||
        normalized.contains('استراحة')) {
      return _SpecialPeriod.breakTime;
    }
    return _SpecialPeriod.none;
  }
}

class _LegacyPeriod {
  const _LegacyPeriod({
    required this.name,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String name;
  final int startMinutes;
  final int durationMinutes;

  int get endMinutes => startMinutes + durationMinutes;
}

enum _SpecialPeriod {
  none,
  assembly,
  breakTime,
}
