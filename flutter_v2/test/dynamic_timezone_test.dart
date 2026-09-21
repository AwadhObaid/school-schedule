import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('representative world IANA zones resolve with full database', () {
    const zones = <String>[
      'Asia/Kuwait',
      'Asia/Tokyo',
      'Europe/London',
      'America/New_York',
      'America/Los_Angeles',
      'Africa/Johannesburg',
      'Australia/Sydney',
      'Pacific/Auckland',
    ];

    for (final zone in zones) {
      expect(() => tz.getLocation(zone), returnsNormally, reason: zone);
    }
  });

  test('DST zones preserve date-specific offsets', () {
    final newYork = tz.getLocation('America/New_York');
    final winter = tz.TZDateTime(newYork, 2026, 1, 15, 9);
    final summer = tz.TZDateTime(newYork, 2026, 7, 15, 9);

    expect(winter.timeZoneOffset, isNot(summer.timeZoneOffset));
  });

  test('scheduler refreshes timezone dynamically and never falls back to UTC', () {
    final source = File(
      'lib/core/services/teacher_notification_scheduler.dart',
    ).readAsStringSync();

    expect(source, contains('Future<bool> refreshTimeZone()'));
    expect(source, contains('FlutterTimezone.getLocalTimezone()'));
    expect(source, contains('resolvedOffset != systemOffset'));
    expect(source, isNot(contains('tz.setLocalLocation(tz.UTC)')));
  });

  test('app refreshes timezone when returning to foreground', () {
    final source = File('lib/main.dart').readAsStringSync();
    final controller = File('lib/core/app_controller.dart').readAsStringSync();

    expect(source, contains('WidgetsBindingObserver'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('handleAppResumed'));
    expect(controller, contains('Future<void> handleAppResumed()'));
  });

  test('Android receiver handles timezone changes while app is closed', () {
    final candidates = <File>[
      File('../tools/phase13f/SchoolScheduleTimeZoneChangeReceiver.java'),
      File(
        'android/app/src/main/java/com/dexterous/flutterlocalnotifications/'
        'SchoolScheduleTimeZoneChangeReceiver.java',
      ),
    ];

    final receiverFile = candidates.firstWhere(
      (file) => file.existsSync(),
      orElse: () => throw StateError(
        'SchoolScheduleTimeZoneChangeReceiver.java was not found in '
        'repository tools or the local Android project.',
      ),
    );

    final source = receiverFile.readAsStringSync();

    expect(source, contains('Intent.ACTION_TIMEZONE_CHANGED'));
    expect(source, contains('Intent.ACTION_TIME_CHANGED'));
    expect(source, contains('ZoneId.systemDefault()'));
    expect(source, contains('rescheduleNotifications(context)'));
  });
}
