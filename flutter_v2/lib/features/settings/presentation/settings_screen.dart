import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/bell_settings.dart';
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
        final notificationSettings = controller.notificationSettings;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'الإعدادات',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'خصص صوت الجرس وتنبيهات حصصك من مكان واحد.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _BellCard(
              settings: controller.bellSettings,
              busy: controller.bellBusy,
              status: controller.bellStatus,
              onEnabledChanged: controller.setBellEnabled,
              onChooseRingtone: controller.pickBellRingtone,
              onResetRingtone: controller.resetBellRingtone,
              onVolumeChanged: controller.setBellVolume,
              onPreview: controller.previewBell,
            ),
            const SizedBox(height: 16),
            _NotificationCard(
              settings: notificationSettings,
              busy: controller.notificationBusy,
              status: controller.notificationStatus,
              preAlertOptions: _preAlertOptions,
              onEnabledChanged: (value) async {
                await controller.setNotificationSettings(
                  notificationSettings.copyWith(enabled: value),
                );
              },
              onPreAlertChanged: (value) async {
                if (value == null) return;
                await controller.setNotificationSettings(
                  notificationSettings.copyWith(preAlertMinutes: value),
                );
              },
              onStartChanged: (value) async {
                await controller.setNotificationSettings(
                  notificationSettings.copyWith(startAlert: value),
                );
              },
              onEndChanged: (value) async {
                await controller.setNotificationSettings(
                  notificationSettings.copyWith(endAlert: value),
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

class _BellCard extends StatefulWidget {
  const _BellCard({
    required this.settings,
    required this.busy,
    required this.status,
    required this.onEnabledChanged,
    required this.onChooseRingtone,
    required this.onResetRingtone,
    required this.onVolumeChanged,
    required this.onPreview,
  });

  final BellSettings settings;
  final bool busy;
  final String status;
  final Future<void> Function(bool value) onEnabledChanged;
  final Future<bool> Function() onChooseRingtone;
  final Future<void> Function() onResetRingtone;
  final Future<void> Function(int value) onVolumeChanged;
  final Future<void> Function() onPreview;

  @override
  State<_BellCard> createState() => _BellCardState();
}

class _BellCardState extends State<_BellCard> {
  late double _draftVolume;

  @override
  void initState() {
    super.initState();
    _draftVolume = widget.settings.volume.toDouble();
  }

  @override
  void didUpdateWidget(covariant _BellCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.volume != widget.settings.volume) {
      _draftVolume = widget.settings.volume.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.enabled,
              onChanged: widget.busy ? null : widget.onEnabledChanged,
              secondary: CircleAvatar(
                backgroundColor: settings.enabled
                    ? const Color(0xFFE6F4EB)
                    : const Color(0xFFF1F3F4),
                child: Icon(
                  settings.enabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: settings.enabled ? AppTheme.primary : Colors.grey,
                ),
              ),
              title: const Text(
                'صوت الجرس المدرسي',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'يعمل عند انتقال فترات الجدول أثناء استخدام التطبيق',
              ),
            ),
            if (widget.busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_rounded),
              title: const Text('النغمة'),
              subtitle: Text(settings.ringtoneName),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: widget.busy ? null : widget.onChooseRingtone,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onChooseRingtone,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('اختيار من الجهاز'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy || settings.usesSystemRingtone
                        ? null
                        : widget.onResetRingtone,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('نغمة النظام'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _draftVolume,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_draftVolume.round()}%',
                    onChanged: widget.busy
                        ? null
                        : (value) {
                            setState(() => _draftVolume = value);
                          },
                    onChangeEnd: widget.busy
                        ? null
                        : (value) => widget.onVolumeChanged(value.round()),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: Text(
                    '${_draftVolume.round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.busy ? null : widget.onPreview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('معاينة النغمة'),
              ),
            ),
            const SizedBox(height: 12),
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
                    widget.status,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                    'ما زال قيد النقل',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'النسخ الاحتياطي ورمز الدخول سيُنقلان من التطبيق القديم في المراحل التالية.',
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
