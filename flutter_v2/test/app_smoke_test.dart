import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/app_controller.dart';
import 'package:schedule/core/models/bell_settings.dart';
import 'package:schedule/core/models/notification_settings.dart';
import 'package:schedule/core/models/school_period.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/services/bell_audio_service.dart';
import 'package:schedule/core/services/teacher_notification_scheduler.dart';
import 'package:schedule/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppController createController() {
    return AppController(
      notificationScheduler: _FakeNotificationScheduler(),
      bellAudioService: _FakeBellAudioService(),
    );
  }

  testWidgets('Flutter V2 opens with Arabic teacher home shell', (tester) async {
    final controller = createController();

    await tester.pumpWidget(SchoolScheduleApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('حصصي'), findsOneWidget);
    expect(find.text('الجدول'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('ابدأ بإضافة حصصك'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('saving a teacher class closes editor before state refresh',
      (tester) async {
    final controller = createController();

    await tester.pumpWidget(SchoolScheduleApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('حصصي'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'الرياضيات');
    await tester.enterText(fields.at(1), 'الصف 8 / 2');

    await tester.tap(find.text('حفظ الحصة'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.textContaining('لديك 1 حصة أسبوعيًا'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('settings expose bell audio controls', (tester) async {
    final controller = createController();

    await tester.pumpWidget(SchoolScheduleApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.text('صوت الجرس المدرسي'), findsOneWidget);
    expect(find.text('اختيار من الجهاز'), findsOneWidget);
    expect(find.text('معاينة النغمة'), findsOneWidget);
    expect(find.text('تنبيهات حصصي'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _FakeNotificationScheduler implements TeacherNotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionResult> requestPermissions() async {
    return const NotificationPermissionResult(
      notificationsGranted: true,
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
  Future<void> cancelTeacherNotifications() async {}

  @override
  Future<void> showTestNotification({String? androidChannelId}) async {}
}

class _FakeBellAudioService implements BellAudioService {
  @override
  Future<String?> configure(BellSettings settings) async {
    return 'teacher_class_alerts_test';
  }

  @override
  Future<BellRingtoneSelection?> pickRingtone() async {
    return const BellRingtoneSelection(
      uri: 'content://school.test/ringtones/bell.mp3',
      name: 'bell.mp3',
    );
  }

  @override
  Future<void> playPreview(BellSettings settings) async {}

  @override
  Future<void> resetRingtone() async {}

  @override
  Future<void> stopPreview() async {}
}
