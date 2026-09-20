import 'dart:convert';

import 'app_appearance.dart';
import 'bell_settings.dart';
import 'notification_settings.dart';
import 'school_schedule_settings.dart';
import 'teacher_class.dart';

class AppBackup {
  const AppBackup({
    required this.appVersion,
    required this.exportedAt,
    required this.pin,
    required this.schoolSchedule,
    required this.teacherClasses,
    required this.notificationSettings,
    required this.bellSettings,
    this.appearance = AppAppearance.light,
    this.ringtoneName,
    this.ringtoneBase64,
  });

  static const format = 'school-schedule-flutter-v2-backup';
  static const backupVersion = 1;

  final String appVersion;
  final DateTime exportedAt;
  final String pin;
  final SchoolScheduleSettings schoolSchedule;
  final List<TeacherClass> teacherClasses;
  final NotificationSettings notificationSettings;
  final BellSettings bellSettings;
  final AppAppearance appearance;
  final String? ringtoneName;
  final String? ringtoneBase64;

  bool get includesCustomRingtone =>
      (ringtoneBase64 ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'backupVersion': backupVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'data': {
        'pin': pin,
        'schoolSchedule': schoolSchedule.toJson(),
        'teacherClasses':
            teacherClasses.map((item) => item.toJson()).toList(growable: false),
        'notificationSettings': notificationSettings.toJson(),
        'bellSettings': bellSettings.toJson(),
        'appearance': appearance.storageValue,
        'ringtone': includesCustomRingtone
            ? {
                'name': ringtoneName,
                'base64': ringtoneBase64,
              }
            : null,
      },
    };
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static BackupParseResult parse(String text) {
    dynamic decoded;

    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const BackupParseResult.failure(
        'الملف ليس نسخة احتياطية JSON صالحة.',
      );
    }

    if (decoded is! Map) {
      return const BackupParseResult.failure(
        'بنية النسخة الاحتياطية غير صالحة.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);

    if (root['format']?.toString() != format) {
      return const BackupParseResult.failure(
        'هذا الملف ليس نسخة احتياطية خاصة بإصدار Flutter V2.',
      );
    }

    final version = int.tryParse(root['backupVersion']?.toString() ?? '');
    if (version == null || version < 1) {
      return const BackupParseResult.failure(
        'رقم إصدار النسخة الاحتياطية غير صالح.',
      );
    }
    if (version > backupVersion) {
      return const BackupParseResult.failure(
        'النسخة الاحتياطية أُنشئت بإصدار أحدث من التطبيق.',
      );
    }

    final rawData = root['data'];
    if (rawData is! Map) {
      return const BackupParseResult.failure(
        'بيانات النسخة الاحتياطية غير موجودة.',
      );
    }

    try {
      final data = Map<String, dynamic>.from(rawData);

      final pin = data['pin']?.toString() ?? '';
      if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
        return const BackupParseResult.failure(
          'رمز الدخول داخل النسخة الاحتياطية غير صالح.',
        );
      }

      final rawSchedule = data['schoolSchedule'];
      if (rawSchedule is! Map) {
        return const BackupParseResult.failure(
          'بيانات الجدول المدرسي غير صالحة.',
        );
      }

      final schoolSchedule = SchoolScheduleSettings.fromJson(
        Map<String, dynamic>.from(rawSchedule),
      );

      if (schoolSchedule.profiles.isEmpty ||
          !schoolSchedule.profiles.containsKey(
            SchoolScheduleSettings.normalProfileId,
          )) {
        return const BackupParseResult.failure(
          'النسخة لا تحتوي على جدول الدوام العادي.',
        );
      }

      final rawClasses = data['teacherClasses'];
      if (rawClasses is! List) {
        return const BackupParseResult.failure(
          'بيانات حصص المدرس غير صالحة.',
        );
      }

      final teacherClasses = <TeacherClass>[];
      for (final raw in rawClasses) {
        if (raw is! Map) {
          return const BackupParseResult.failure(
            'يوجد سجل حصة غير صالح داخل النسخة.',
          );
        }

        final item = TeacherClass.fromJson(Map<String, dynamic>.from(raw));
        if (item.weekday < DateTime.monday ||
            item.weekday > DateTime.sunday ||
            item.periodId.trim().isEmpty ||
            item.subject.trim().isEmpty) {
          return const BackupParseResult.failure(
            'يوجد سجل حصة ناقص أو غير صالح داخل النسخة.',
          );
        }
        teacherClasses.add(item);
      }

      final rawNotification = data['notificationSettings'];
      final notificationSettings = rawNotification is Map
          ? NotificationSettings.fromJson(
              Map<String, dynamic>.from(rawNotification),
            )
          : const NotificationSettings();

      final rawBell = data['bellSettings'];
      final bellSettings = rawBell is Map
          ? BellSettings.fromJson(Map<String, dynamic>.from(rawBell))
          : const BellSettings();

      final appearance = AppAppearance.fromStorage(
        data['appearance']?.toString(),
      );

      String? ringtoneName;
      String? ringtoneBase64;
      final rawRingtone = data['ringtone'];
      if (rawRingtone is Map) {
        final ringtone = Map<String, dynamic>.from(rawRingtone);
        ringtoneName = ringtone['name']?.toString().trim();
        ringtoneBase64 = ringtone['base64']?.toString().trim();

        if ((ringtoneBase64 ?? '').isNotEmpty) {
          try {
            final estimatedBytes = (ringtoneBase64!.length * 3) ~/ 4;
            if (estimatedBytes > 20 * 1024 * 1024 + 16) {
              return const BackupParseResult.failure(
                'ملف النغمة داخل النسخة أكبر من الحد المسموح.',
              );
            }
            base64Decode(ringtoneBase64);
          } catch (_) {
            return const BackupParseResult.failure(
              'بيانات ملف النغمة داخل النسخة غير صالحة.',
            );
          }
        }
      }

      final exportedAt = DateTime.tryParse(
            root['exportedAt']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return BackupParseResult.success(
        AppBackup(
          appVersion: root['appVersion']?.toString() ?? '',
          exportedAt: exportedAt,
          pin: pin,
          schoolSchedule: schoolSchedule,
          teacherClasses: List<TeacherClass>.unmodifiable(teacherClasses),
          notificationSettings: notificationSettings,
          bellSettings: bellSettings,
          appearance: appearance,
          ringtoneName: ringtoneName,
          ringtoneBase64: ringtoneBase64,
        ),
      );
    } catch (_) {
      return const BackupParseResult.failure(
        'تعذر قراءة إحدى بيانات النسخة الاحتياطية.',
      );
    }
  }
}

class BackupParseResult {
  const BackupParseResult.success(this.backup)
      : error = null;

  const BackupParseResult.failure(this.error)
      : backup = null;

  final AppBackup? backup;
  final String? error;

  bool get isValid => backup != null && error == null;
}
