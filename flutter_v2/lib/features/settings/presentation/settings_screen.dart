import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/app_info.dart';
import '../../../core/models/app_appearance.dart';
import '../../../core/models/app_backup.dart';
import '../../../core/models/bell_settings.dart';
import '../../../core/models/notification_settings.dart';
import '../../../core/models/school_notification_settings.dart';
import '../../../core/services/legacy_backup_migration.dart';
import '../../../core/theme/app_theme.dart';
import '../../update/presentation/update_dialog.dart';

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
        final schoolNotificationSettings =
            controller.schoolNotificationSettings;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'الإعدادات',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'خصص صوت الجرس وتنبيهات الجدول المدرسي وتنبيهات حصصك من مكان واحد.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _AppearanceCard(
              value: controller.appearance,
              onChanged: controller.setAppearance,
            ),
            const SizedBox(height: 16),
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
            _SchoolNotificationCard(
              settings: schoolNotificationSettings,
              busy: controller.schoolNotificationBusy,
              status: controller.schoolNotificationStatus,
              onEnabledChanged: (value) async {
                await controller.setSchoolNotificationSettings(
                  schoolNotificationSettings.copyWith(enabled: value),
                );
              },
              onTest: controller.showSchoolScheduleTestNotification,
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
            _BackupSecurityCard(controller: controller),
            const SizedBox(height: 16),
            _UpdateCard(controller: controller),
            const SizedBox(height: 16),
            _AboutCard(controller: controller),
          ],
        );
      },
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.value,
    required this.onChanged,
  });

  final AppAppearance value;
  final Future<void> Function(AppAppearance value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.dark_mode_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'المظهر',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<AppAppearance>(
              segments: const [
                ButtonSegment(
                  value: AppAppearance.system,
                  icon: Icon(Icons.phone_android_rounded),
                  label: Text('النظام'),
                ),
                ButtonSegment(
                  value: AppAppearance.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('فاتح'),
                ),
                ButtonSegment(
                  value: AppAppearance.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('داكن'),
                ),
              ],
              selected: <AppAppearance>{value},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onChanged(selection.first);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'يحفظ التطبيق اختيارك ويطبقه تلقائيًا عند التشغيل التالي.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  settings.enabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: settings.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              title: const Text(
                'صوت الجرس المدرسي',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'يستخدم Android لتشغيل الجرس في مواعيد الجدول حتى مع قفل الشاشة أو وجود التطبيق في الخلفية',
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
                  color: settings.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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

class _SchoolNotificationCard extends StatelessWidget {
  const _SchoolNotificationCard({
    required this.settings,
    required this.busy,
    required this.status,
    required this.onEnabledChanged,
    required this.onTest,
  });

  final SchoolNotificationSettings settings;
  final bool busy;
  final String status;
  final ValueChanged<bool> onEnabledChanged;
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
              secondary: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.schedule_send_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                'تنبيهات الجدول المدرسي',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'بداية ونهاية جميع فترات الدوام حتى إذا لم تستخدم «حصصي»',
              ),
            ),
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  settings.enabled
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: settings.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 12),
            Text(
              'تتبع هذه التنبيهات الجدول الفعلي لكل يوم، بما في ذلك رمضان والجداول المخصصة والطابور والفسحة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onTest,
                icon: const Icon(Icons.notifications_none_rounded),
                label: const Text('اختبار تنبيهات الجدول الآن'),
              ),
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
              secondary: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Theme.of(context).colorScheme.primary,
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
                  color: settings.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                onPressed: busy ? null : onTest,
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

class _BackupSecurityCard extends StatefulWidget {
  const _BackupSecurityCard({
    required this.controller,
  });

  final AppController controller;

  @override
  State<_BackupSecurityCard> createState() => _BackupSecurityCardState();
}

class _BackupSecurityCardState extends State<_BackupSecurityCard> {
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  bool _changingPin = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.controller.backupBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.security_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الحماية والنسخ الاحتياطي',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('رمز دخول الإعدادات'),
              subtitle: const Text(
                'يُطلب الرمز كل مرة تفتح فيها الإعدادات. الافتراضي 0000.',
              ),
              trailing: TextButton(
                onPressed: () {
                  setState(() => _changingPin = !_changingPin);
                },
                child: Text(_changingPin ? 'إلغاء' : 'تغيير'),
              ),
            ),
            if (_changingPin) ...[
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'الرمز الجديد',
                  hintText: 'من 4 إلى 12 رقمًا',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pinConfirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'تأكيد الرمز',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _savePin,
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ رمز الدخول'),
              ),
              const SizedBox(height: 10),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'النسخ الاحتياطي والاستعادة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'تشمل النسخة: الجدول، حصصي، إعدادات التنبيهات والجرس، رمز الدخول، وملف النغمة المخصصة إن وجد.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : widget.controller.exportBackup,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('تصدير نسخة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _restoreBackup,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('استعادة نسخة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : _migrateLegacyBackup,
              icon: const Icon(Icons.move_down_rounded),
              label: const Text('استيراد من التطبيق القديم'),
            ),
            const SizedBox(height: 6),
            Text(
              'يقبل ملف JSON الذي صدّرته النسخة القديمة 1.4.2. حصص Flutter الشخصية والمظهر الحالي لا يتم حذفهما أثناء الترحيل.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.controller.backupStatus,
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

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _pinConfirmController.text.trim();

    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      _message('رمز الدخول يجب أن يتكوّن من 4 إلى 12 رقمًا.');
      return;
    }

    if (pin != confirm) {
      _message('تأكيد رمز الدخول غير مطابق.');
      return;
    }

    final saved = await widget.controller.changeSettingsPin(pin);
    if (!mounted) return;

    if (saved) {
      _pinController.clear();
      _pinConfirmController.clear();
      setState(() => _changingPin = false);
      _message('تم تغيير رمز الدخول بنجاح.');
    }
  }

  Future<void> _restoreBackup() async {
    final result = await widget.controller.pickBackup();
    if (!mounted || result == null || !result.isValid) {
      final error = result?.error;
      if (error != null) _message(error);
      return;
    }

    final backup = result.backup!;
    final accepted = await _confirmBackup(backup);
    if (!mounted || accepted != true) return;

    final restored = await widget.controller.applyBackup(backup);
    if (!mounted) return;

    if (restored) {
      _message('تمت استعادة النسخة الاحتياطية بنجاح.');
    }
  }

  Future<void> _migrateLegacyBackup() async {
    final result = await widget.controller.pickLegacyBackup();

    if (!mounted || result == null || !result.isValid) {
      final error = result?.error;
      if (error != null) _message(error);
      return;
    }

    final data = result.data!;
    final accepted = await _confirmLegacyMigration(data);
    if (!mounted || accepted != true) return;

    final migrated = await widget.controller.applyLegacyMigration(data);
    if (!mounted) return;

    if (migrated) {
      _message('تم ترحيل بيانات التطبيق القديم بنجاح.');
    }
  }

  Future<bool?> _confirmLegacyMigration(LegacyMigrationData data) {
    final warnings = data.warnings
        .map((item) => '• $item')
        .join('\n');

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ترحيل بيانات التطبيق القديم؟'),
        content: Text(
          'إصدار المصدر: ${data.sourceVersion}\n'
          'عدد الجداول: ${data.scheduleCount}\n'
          'نغمة مخصصة قديمة: ${data.hadCustomRingtone ? 'نعم' : 'لا'}\n\n'
          '$warnings\n\n'
          'سيتم استبدال الجداول وPIN وإعدادات الجرس وتنبيهات الجدول العامة بالقيم القديمة، بينما تبقى «حصصي» وتنبيهاتها الشخصية والمظهر الحالي محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بدء الترحيل'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmBackup(AppBackup backup) {
    final date = backup.exportedAt.millisecondsSinceEpoch == 0
        ? 'غير معروف'
        : backup.exportedAt.toLocal().toString().split('.').first;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة النسخة الاحتياطية؟'),
        content: Text(
          'تاريخ النسخة: $date\n'
          'حصص المدرس: ${backup.teacherClasses.length}\n'
          'نغمة مخصصة مرفقة: ${backup.includesCustomRingtone ? 'نعم' : 'لا'}\n\n'
          'سيتم استبدال الإعدادات والبيانات الحالية بعد التأكيد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}


class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.system_update_alt_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'التحديثات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_outlined),
              title: Text('الإصدار الحالي'),
              subtitle: Text(
                AppInfo.version,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton.tonalIcon(
              onPressed: controller.updateBusy
                  ? null
                  : () async {
                      final result = await controller.checkForUpdates(
                        silent: false,
                        respectIgnored: false,
                      );

                      if (!context.mounted) return;

                      if (result.hasUpdate) {
                        await showAppUpdateDialog(
                          context,
                          controller: controller,
                          update: result.update!,
                        );
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    },
              icon: controller.updateBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('التحقق من التحديثات'),
            ),
            const SizedBox(height: 10),
            Text(
              controller.updateStatus,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'يتم التحقق من أحدث إصدار منشور في GitHub Releases. إذا احتوى الإصدار على ملف APK سيفتح زر التحديث رابط التنزيل مباشرة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.info_outline_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حول التطبيق',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline_rounded),
              title: Text('المطور'),
              subtitle: Text(
                AppInfo.developerName,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.apps_rounded),
              title: Text(AppInfo.appName),
              subtitle: Text('الإصدار ${AppInfo.version}'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final shared = await controller.shareApplication();
                if (!context.mounted || shared) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تعذر فتح نافذة مشاركة التطبيق.'),
                  ),
                );
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة التطبيق'),
            ),
            const SizedBox(height: 8),
            Text(
              'رابط المشاركة الحالي يفتح صفحة المشروع على GitHub، وسيُستبدل بالرابط المباشر للإصدار المستقر عند النشر النهائي.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
