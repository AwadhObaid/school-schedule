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

  test(
    'enabling school bell schedules Android school alerts even when general alerts are off',
    () async {
      final scheduler = _RecordingNotificationScheduler();
      final controller = AppController(
        notificationScheduler: scheduler,
        bellAudioService: _FakeBellAudioService(),
      );

      await controller.initialize();
      expect(controller.schoolNotificationSettings.enabled, isFalse);

      await controller.setBellEnabled(true);

      expect(controller.bellSettings.enabled, isTrue);
      expect(scheduler.schoolSyncCalls, 1);
      expect(scheduler.lastSchoolEnabled, isTrue);
      expect(scheduler.lastSchoolChannelId, 'school_bell_test_channel');

      controller.dispose();
    },
  );

  test(
    'disabling bell cancels school transport when general school alerts are off',
    () async {
      final scheduler = _RecordingNotificationScheduler();
      final controller = AppController(
        notificationScheduler: scheduler,
        bellAudioService: _FakeBellAudioService(),
      );

      await controller.initialize();
      await controller.setBellEnabled(true);
      await controller.setBellEnabled(false);

      expect(controller.bellSettings.enabled, isFalse);
      expect(scheduler.schoolCancelCalls, greaterThanOrEqualTo(1));

      controller.dispose();
    },
  );

  test(
    'general school alerts keep schedule active after bell is disabled',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'school_notification_settings_v1': '{"enabled":true}',
      });

      final scheduler = _RecordingNotificationScheduler();
      final controller = AppController(
        notificationScheduler: scheduler,
        bellAudioService: _FakeBellAudioService(),
      );

      await controller.initialize();
      await controller.setBellEnabled(true);
      final syncBeforeDisable = scheduler.schoolSyncCalls;

      await controller.setBellEnabled(false);

      expect(controller.schoolNotificationSettings.enabled, isTrue);
      expect(scheduler.schoolSyncCalls, greaterThan(syncBeforeDisable));
      expect(scheduler.lastSchoolEnabled, isTrue);
      expect(scheduler.lastSchoolChannelId, isNull);

      controller.dispose();
    },
  );

  test(
    'bell stays disabled when notification permission is denied',
    () async {
      final scheduler = _RecordingNotificationScheduler(
        notificationsGranted: false,
      );
      final controller = AppController(
        notificationScheduler: scheduler,
        bellAudioService: _FakeBellAudioService(),
      );

      await controller.initialize();
      await controller.setBellEnabled(true);

      expect(controller.bellSettings.enabled, isFalse);
      expect(controller.bellStatus, contains('إذن الإشعارات'));

      controller.dispose();
    },
  );
}

class _RecordingNotificationScheduler implements TeacherNotificationScheduler {
  _RecordingNotificationScheduler({
    this.notificationsGranted = true,
  });

  final bool notificationsGranted;

  int schoolSyncCalls = 0;
  int schoolCancelCalls = 0;
  bool? lastSchoolEnabled;
  String? lastSchoolChannelId;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionResult> requestPermissions() async {
    return NotificationPermissionResult(
      notificationsGranted: notificationsGranted,
      exactAlarmsGranted: true,
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
    lastSchoolEnabled = enabled;
    lastSchoolChannelId = androidChannelId;
  }

  @override
  Future<void> cancelTeacherNotifications() async {}

  @override
  Future<void> cancelSchoolScheduleNotifications() async {
    schoolCancelCalls += 1;
  }

  @override
  Future<void> showTestNotification({String? androidChannelId}) async {}

  @override
  Future<void> showSchoolScheduleTestNotification({
    String? androidChannelId,
  }) async {}
}

class _FakeBellAudioService implements BellAudioService {
  @override
  Future<String?> configure(BellSettings settings) async {
    return 'school_bell_test_channel';
  }

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
  }) async {
    return null;
  }
}
