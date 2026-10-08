import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('Asia/Kuwait alias is available and keeps local wall time', () {
    tz_data.initializeTimeZones();
    final kuwait = tz.getLocation('Asia/Kuwait');
    final local = tz.TZDateTime(kuwait, 2026, 9, 21, 17, 2);

    expect(local.timeZoneOffset, const Duration(hours: 3));
    expect(local.toUtc(), DateTime.utc(2026, 9, 21, 14, 2));
  });

  test('notification scheduler uses full tz database and no UTC fallback', () {
    final source = File(
      'lib/core/services/teacher_notification_scheduler.dart',
    ).readAsStringSync();

    expect(source, contains("package:timezone/data/latest_all.dart"));
    expect(source, contains('FlutterTimezone.getLocalTimezone()'));
    expect(source, contains('resolvedOffset != systemOffset'));
    expect(source, isNot(contains('tz.setLocalLocation(tz.UTC)')));
  });
}
