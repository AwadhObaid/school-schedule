import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification scheduler uses retained Android drawable name', () {
    final source = File(
      'lib/core/services/teacher_notification_scheduler.dart',
    ).readAsStringSync();

    expect(source, contains("AndroidInitializationSettings('ic_stat_schedule')"));
    expect(source, contains("icon: 'ic_stat_schedule'"));
    expect(source, isNot(contains('ic_stat_school')));
  });
}
