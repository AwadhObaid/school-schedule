import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/app_controller.dart';
import 'package:schedule/core/models/bell_settings.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/models/school_period.dart';
import 'package:schedule/core/models/school_schedule_settings.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/bell_audio_service.dart';
import 'package:schedule/core/services/teacher_notification_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('school test requests permission and rearms schedules', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'school_notification_settings_v1': '{"enabled":true}',
    });

    final scheduler = _Scheduler();
    final controller = AppController(
      notificationScheduler: scheduler,
      bellAudioService: _Bell(),
    );

    await controller.initialize();
    final before = scheduler.schoolSyncCalls;

    await controller.showSchoolScheduleTestNotification();

    expect(scheduler.permissionRequests, greaterThanOrEqualTo(1));
    expect(scheduler.schoolSyncCalls, greaterThan(before));
    expect(scheduler.schoolTests, 1);
    expect(controller.schoolNotificationStatus, contains('تم إرسال'));

    controller.dispose();
  });

  test('teacher test reports denied permission instead of silently failing', () async {
    final scheduler = _Scheduler(granted: false);
    final controller = AppController(
      notificationScheduler: scheduler,
      bellAudioService: _Bell(),
    );

    await controller.initialize();
    await controller.showTestNotification();

    expect(scheduler.teacherTests, 0);
    expect(controller.notificationStatus, contains('إذن الإشعارات'));

    controller.dispose();
  });
}

class _Scheduler implements TeacherNotificationScheduler {
  _Scheduler({this.granted = true});

  final bool granted;
  int permissionRequests = 0;
  int schoolSyncCalls = 0;
  int schoolTests = 0;
  int teacherTests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionResult> requestPermissions() async {
    permissionRequests += 1;
    return NotificationPermissionResult(
      notificationsGranted: granted,
      exactAlarmsGranted: granted,
    );
  }

  @override
  Future<void> sync({
    required List<TeacherClass> assignments,
    required Map<int, List<SchoolPeriod>> periodsByWeekday,
    required NotificationSettings settings,
    String? androidChannelId,
  }) async {}

  @override
  Future<void> syncSchoolSchedule({
    required SchoolScheduleSettings schedule,
    required bool enabled,
    String? androidChannelId,
  }) async {
    schoolSyncCalls += 1;
  }

  @override
  Future<void> cancelTeacherNotifications() async {}

  @override
  Future<void> cancelSchoolScheduleNotifications() async {}

  @override
  Future<bool> showTestNotification({String? androidChannelId}) async {
    teacherTests += 1;
    return granted;
  }

  @override
  Future<bool> showSchoolScheduleTestNotification({
    String? androidChannelId,
  }) async {
    schoolTests += 1;
    return granted;
  }
}

class _Bell implements BellAudioService {
  @override
  Future<String?> configure(BellSettings settings) async =>
      'school_bell_test_channel';

  @override
  Future<BellRingtoneSelection?> pickRingtone() async => null;

  @override
  Future<void> playPreview(BellSettings settings) async {}

  @override
  Future<void> resetRingtone() async {}

  @override
  Future<void> stopPreview() async {}

  @override
  Future<BellRingtoneBackup?> exportRingtone() async => null;

  @override
  Future<BellRingtoneSelection?> restoreRingtone({
    required String name,
    required String base64,
  }) async => null;
}
