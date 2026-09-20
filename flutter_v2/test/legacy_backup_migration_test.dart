import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/school_schedule_settings.dart';
import 'package:schedule/core/services/legacy_backup_migration.dart';

void main() {
  test('migrates wrapped legacy 1.4.2 backup into Flutter V2 models', () {
    final legacy = <String, dynamic>{
      'format': 'school-schedule-backup',
      'backupVersion': 1,
      'appVersion': '1.4.2',
      'exportedAt': '2026-09-20T12:00:00.000Z',
      'state': <String, dynamic>{
        'schemaVersion': 4,
        'ramadanMode': true,
        'pin': '2468',
        'soundEnabled': true,
        'notificationsEnabled': true,
        'bellVolume': 65,
        'ringtoneUri': 'content://legacy/ringtone',
        'ringtoneName': 'school-bell.mp3',
        'weekdayMap': <String, dynamic>{
          '0': 'normal',
          '1': 'custom_short',
          '2': 'normal',
          '3': 'normal',
          '4': 'normal',
          '5': 'off',
          '6': 'off',
        },
        'schedules': <String, dynamic>{
          'normal': <String, dynamic>{
            'name': 'الدوام العادي',
            'periods': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'الطابور',
                'start': '07:30',
                'duration': 15,
              },
              <String, dynamic>{
                'name': 'الحصة 1',
                'start': '07:45',
                'duration': 35,
              },
              <String, dynamic>{
                'name': 'الفسحة',
                'start': '08:20',
                'duration': 20,
              },
              <String, dynamic>{
                'name': 'الحصة 2',
                'start': '08:40',
                'duration': 35,
              },
            ],
          },
          'custom_short': <String, dynamic>{
            'name': 'دوام قصير',
            'periods': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'الحصة الأولى',
                'start': '09:00',
                'duration': 30,
              },
              <String, dynamic>{
                'name': 'الحصة الثانية',
                'start': '09:40',
                'duration': 30,
              },
            ],
          },
        },
      },
    };

    final result = LegacyBackupMigration.parse(jsonEncode(legacy));

    expect(result.isValid, isTrue);

    final data = result.data!;
    expect(data.sourceVersion, '1.4.2');
    expect(data.pin, '2468');
    expect(data.scheduleCount, 2);
    expect(data.schoolSchedule.ramadanMode, isTrue);
    expect(data.notificationSettings.enabled, isTrue);
    expect(data.notificationSettings.preAlertMinutes, 0);
    expect(data.bellSettings.enabled, isTrue);
    expect(data.bellSettings.volume, 65);

    expect(data.hadCustomRingtone, isTrue);
    expect(data.bellSettings.ringtoneUri, isEmpty);
    expect(data.bellSettings.ringtoneName, 'نغمة النظام');

    expect(
      data.schoolSchedule.weekdayMap[DateTime.sunday],
      SchoolScheduleSettings.normalProfileId,
    );
    expect(
      data.schoolSchedule.weekdayMap[DateTime.monday],
      'custom_short',
    );
    expect(
      data.schoolSchedule.weekdayMap[DateTime.friday],
      SchoolScheduleSettings.offProfileId,
    );

    final normal =
        data.schoolSchedule.profiles[SchoolScheduleSettings.normalProfileId]!;
    expect(normal.periods[0].id, 'assembly');
    expect(normal.periods[0].teacherSelectable, isFalse);
    expect(normal.periods[1].id, 'p1');
    expect(normal.periods[2].id, 'break');
    expect(normal.periods[2].teacherSelectable, isFalse);
    expect(normal.periods[3].id, 'p2');

    expect(
      data.schoolSchedule.profiles.containsKey(
        SchoolScheduleSettings.ramadanProfileId,
      ),
      isTrue,
    );
    expect(data.warnings, isNotEmpty);
  });

  test('accepts raw legacy state without backup wrapper', () {
    final result = LegacyBackupMigration.parse(
      jsonEncode(
        <String, dynamic>{
          'schemaVersion': 4,
          'ramadanMode': false,
          'pin': '0000',
          'soundEnabled': false,
          'notificationsEnabled': false,
          'bellVolume': 80,
          'ringtoneUri': '',
          'ringtoneName': 'نغمة النظام',
          'weekdayMap': <String, dynamic>{
            '0': 'normal',
            '1': 'normal',
            '2': 'normal',
            '3': 'normal',
            '4': 'normal',
            '5': 'off',
            '6': 'off',
          },
          'schedules': <String, dynamic>{
            'normal': <String, dynamic>{
              'name': 'الدوام العادي',
              'periods': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'الحصة 1',
                  'start': '08:00',
                  'duration': 35,
                },
              ],
            },
          },
        },
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.data?.pin, '0000');
    expect(result.data?.hadCustomRingtone, isFalse);
  });

  test('rejects overlapping legacy periods', () {
    final result = LegacyBackupMigration.parse(
      jsonEncode(
        <String, dynamic>{
          'pin': '0000',
          'schedules': <String, dynamic>{
            'normal': <String, dynamic>{
              'name': 'الدوام',
              'periods': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'الحصة 1',
                  'start': '08:00',
                  'duration': 60,
                },
                <String, dynamic>{
                  'name': 'الحصة 2',
                  'start': '08:30',
                  'duration': 35,
                },
              ],
            },
          },
        },
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.error, contains('تداخل'));
  });

  test('rejects backup from another application', () {
    final result = LegacyBackupMigration.parse(
      '{"format":"other-app","backupVersion":1,"state":{}}',
    );

    expect(result.isValid, isFalse);
  });
}
