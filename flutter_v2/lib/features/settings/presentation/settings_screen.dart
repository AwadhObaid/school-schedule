import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/notification_settings.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  static const _preAlertOptions = <int>[0, 1, 3, 5, 10, 15];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.notificationSettings;
        final busy = controller.notificationBusy;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'الإعدادات',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'خصص تنبيهات حصصك. إعدادات الجرس العام والنغمة ستُنقل من التطبيق القديم في مرحلة لاحقة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _NotificationCard(
              settings: settings,
              busy: busy,
              status: controller.notificationStatus,
              preAlertOptions: _preAlertOptions,
              onEnabledChanged: (value) async {
                await controller.setNotificationSettings(
                  settings.copyWith(enabled: value),
                );
              },
              onPreAlertChanged: (value) async {
                if (value == null) return;
                await controller.setNotificationSettings(
                  settings.copyWith(preAlertMinutes: value),
                );
              },
              onStartChanged: (value) async {
                await controller.setNotificationSettings(
                  settings.copyWith(startAlert: value),
                );
              },
              onEndChanged: (value) async {
                await controller.setNotificationSettings(
                  settings.copyWith(endAlert: value),
                );
              },
              onTest: controller.showTestNotification,
            ),
            const SizedBox(height: 16),
            const _ComingLaterCard(),
          ],
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.settings,
    required this.busy,
    required this.status,
    required this.preAlertOptions,
    required this.onEnabledChanged,
    required this.onPreAlertChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onTest,
  });

  final NotificationSettings settings;
  final bool busy;
  final String status;
  final List<int> preAlertOptions;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int?> onPreAlertChanged;
  final ValueChanged<bool> onStartChanged;
  final ValueChanged<bool> onEndChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final enabled = settings.enabled && !busy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.enabled,
              onChanged: busy ? null : onEnabledChanged,
              secondary: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4EB),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.primary,
                ),
              ),
              title: const Text(
                'تنبيهات حصصي',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'تنبيهات تلقائية مرتبطة بجدول حصصك الأسبوعي',
              ),
            ),
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('التنبيه قبل الحصة'),
              subtitle: Text(
                settings.preAlertMinutes == 0
                    ? 'بدون تنبيه مسبق'
                    : 'قبل الموعد بـ ${settings.preAlertMinutes} دقائق',
              ),
              trailing: DropdownButton<int>(
                value: settings.preAlertMinutes,
                onChanged: enabled ? onPreAlertChanged : null,
                items: preAlertOptions
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value == 0 ? 'إيقاف' : '$value د'),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.startAlert,
              onChanged: enabled ? onStartChanged : null,
              secondary: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('تنبيه بداية الحصة'),
              subtitle: const Text(
                'يعرض رقم الحصة والمادة والصف عند بداية الوقت',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.endAlert,
              onChanged: enabled ? onEndChanged : null,
              secondary: const Icon(Icons.flag_outlined),
              title: const Text('تنبيه نهاية الحصة'),
              subtitle: const Text(
                'يخبرك بانتهاء الحصة وما هي الحصة التالية',
              ),
            ),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  settings.enabled
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: settings.enabled ? AppTheme.primary : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: enabled ? onTest : null,
                icon: const Icon(Icons.notifications_none_rounded),
                label: const Text('اختبار التنبيه الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingLaterCard extends StatelessWidget {
  const _ComingLaterCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tune_rounded, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إعدادات التطبيق القديم',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نغمة الجرس، مستوى الصوت، النسخ الاحتياطي ورمز الدخول ستُنقل تدريجيًا مع الحفاظ على سلوك النسخة الحالية.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
