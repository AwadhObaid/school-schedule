import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/data/school_schedule_defaults.dart';
import 'package:schedule/core/models/app_appearance.dart';
import 'package:schedule/core/models/app_backup.dart';
import 'package:schedule/core/models/bell_settings.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/models/school_notification_settings.dart';
import 'package:schedule/core/models/teacher_class.dart';

void main() {
  test('Flutter V2 backup round-trips all core settings', () {
    final backup = AppBackup(
      appVersion: '2.6.0+15',
      exportedAt: DateTime.utc(2026, 9, 20, 18, 0),
      pin: '2468',
      schoolSchedule:
          SchoolScheduleDefaults.settings.copyWith(ramadanMode: true),
      teacherClasses: const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p2',
          subject: 'اللغة الإنجليزية',
          classroom: 'الصف 8 / 2',
        ),
      ],
      notificationSettings: const NotificationSettings(
        enabled: true,
        preAlertMinutes: 5,
      ),
      schoolNotificationSettings:
          const SchoolNotificationSettings(enabled: true),
      bellSettings: const BellSettings(
        enabled: true,
        ringtoneUri: 'content://school/ringtone',
        ringtoneName: 'bell.mp3',
        volume: 65,
      ),
      appearance: AppAppearance.dark,
      ringtoneName: 'bell.mp3',
      ringtoneBase64: 'AQIDBA==',
    );

    final parsed = AppBackup.parse(backup.encode());

    expect(parsed.isValid, isTrue);
    expect(parsed.backup?.pin, '2468');
    expect(parsed.backup?.teacherClasses, hasLength(1));
    expect(parsed.backup?.notificationSettings.enabled, isTrue);
    expect(parsed.backup?.schoolNotificationSettings.enabled, isTrue);
    expect(parsed.backup?.bellSettings.volume, 65);
    expect(parsed.backup?.appearance, AppAppearance.dark);
    expect(parsed.backup?.includesCustomRingtone, isTrue);
    expect(parsed.backup?.schoolSchedule.ramadanMode, isTrue);
  });

  test('older backups without general notification settings remain valid', () {
    final backup = AppBackup(
      appVersion: '2.8.0+17',
      exportedAt: DateTime.utc(2026, 9, 20, 18, 0),
      pin: '0000',
      schoolSchedule: SchoolScheduleDefaults.settings,
      teacherClasses: const <TeacherClass>[],
      notificationSettings: const NotificationSettings(),
      bellSettings: const BellSettings(),
    );

    final map = backup.toJson();
    final data = Map<String, dynamic>.from(map['data'] as Map);
    data.remove('schoolNotificationSettings');
    map['data'] = data;

    final parsed = AppBackup.parse(
      const JsonEncoder.withIndent('  ').convert(map),
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.backup?.schoolNotificationSettings.enabled, isFalse);
  });

  test('older Phase 06 backup without appearance defaults to light', () {
    final backup = AppBackup(
      appVersion: '2.5.0+14',
      exportedAt: DateTime.utc(2026, 9, 20, 18, 0),
      pin: '0000',
      schoolSchedule: SchoolScheduleDefaults.settings,
      teacherClasses: const <TeacherClass>[],
      notificationSettings: const NotificationSettings(),
      bellSettings: const BellSettings(),
    );

    final map = backup.toJson();
    final data = Map<String, dynamic>.from(map['data'] as Map);
    data.remove('appearance');
    map['data'] = data;

    final parsed = AppBackup.parse(
      const JsonEncoder.withIndent('  ').convert(map),
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.backup?.appearance, AppAppearance.light);
  });

  test('rejects a backup belonging to another format', () {
    final parsed = AppBackup.parse(
      '{"format":"other-app","backupVersion":1,"data":{}}',
    );

    expect(parsed.isValid, isFalse);
    expect(parsed.error, isNotEmpty);
  });

  test('rejects a future backup version', () {
    final parsed = AppBackup.parse(
      '{"format":"school-schedule-flutter-v2-backup",'
      '"backupVersion":99,"data":{}}',
    );

    expect(parsed.isValid, isFalse);
    expect(parsed.error, contains('أحدث'));
  });
}
