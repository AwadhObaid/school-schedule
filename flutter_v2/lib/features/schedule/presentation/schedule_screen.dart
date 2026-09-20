import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/school_period.dart';
import '../../../core/models/school_schedule_settings.dart';
import '../../../core/utils/arabic_format.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _selectedProfileId = SchoolScheduleSettings.normalProfileId;

  static const _days = <(int, String)>[
    (DateTime.sunday, 'الأحد'),
    (DateTime.monday, 'الاثنين'),
    (DateTime.tuesday, 'الثلاثاء'),
    (DateTime.wednesday, 'الأربعاء'),
    (DateTime.thursday, 'الخميس'),
    (DateTime.friday, 'الجمعة'),
    (DateTime.saturday, 'السبت'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final schedule = widget.controller.schoolSchedule;
        final selectedId = schedule.profiles.containsKey(_selectedProfileId)
            ? _selectedProfileId
            : SchoolScheduleSettings.normalProfileId;
        final selectedProfile = schedule.profiles[selectedId];

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'الجدول المدرسي',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'أنشئ أكثر من جدول وعيّن الجدول المناسب لكل يوم. «حصصي» والتنبيهات تتبع الجدول الفعلي تلقائيًا.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _RamadanCard(
              enabled: schedule.ramadanMode,
              onChanged: widget.controller.setRamadanMode,
            ),
            const SizedBox(height: 14),
            _WeekdayMapCard(
              schedule: schedule,
              days: _days,
              onChanged: widget.controller.setWeekdayProfile,
            ),
            const SizedBox(height: 14),
            if (selectedProfile != null)
              _ProfileManagerCard(
                selectedProfileId: selectedId,
                profile: selectedProfile,
                profiles: schedule.profiles,
                builtIn: widget.controller.isBuiltInProfile(selectedId),
                onProfileChanged: (value) {
                  setState(() => _selectedProfileId = value);
                },
                onCreateBlank: () => _createProfile(
                  context,
                  sourceProfileId: null,
                ),
                onDuplicate: () => _createProfile(
                  context,
                  sourceProfileId: selectedId,
                ),
                onRename: () => _renameProfile(
                  context,
                  selectedId,
                  selectedProfile.name,
                ),
                onDeleteProfile: () => _deleteProfile(
                  context,
                  selectedId,
                  selectedProfile.name,
                ),
                onAddPeriod: () => _addPeriod(context, selectedId),
                onEditPeriod: (period) =>
                    _editPeriod(context, selectedId, period),
                onDeletePeriod: (period) => _deletePeriod(
                  context,
                  selectedId,
                  period,
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _confirmReset(context),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('استعادة الجداول الافتراضية'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createProfile(
    BuildContext context, {
    required String? sourceProfileId,
  }) async {
    final title = sourceProfileId == null
        ? 'إنشاء جدول جديد'
        : 'نسخ الجدول الحالي';
    final name = await _askForName(
      context,
      title: title,
      initialValue: sourceProfileId == null ? '' : 'نسخة جديدة',
    );
    if (name == null) return;

    final id = await widget.controller.createScheduleProfile(
      name: name,
      sourceProfileId: sourceProfileId,
    );

    if (!mounted) return;
    setState(() => _selectedProfileId = id);
  }

  Future<void> _renameProfile(
    BuildContext context,
    String profileId,
    String currentName,
  ) async {
    final name = await _askForName(
      context,
      title: 'إعادة تسمية الجدول',
      initialValue: currentName,
    );
    if (name == null) return;

    final renamed = await widget.controller.renameScheduleProfile(
      profileId,
      name,
    );

    if (!mounted || renamed) return;
    _message('تعذر إعادة تسمية هذا الجدول.');
  }

  Future<void> _deleteProfile(
    BuildContext context,
    String profileId,
    String profileName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الجدول؟'),
        content: Text(
          'سيتم حذف «$profileName». أي يوم يستخدم هذا الجدول سيتحول إلى إجازة. حصص المدرس تبقى محفوظة، لكنها لن تعمل ما دام لا يوجد لها وقت صالح.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await widget.controller.deleteScheduleProfile(profileId);
    if (!mounted) return;

    if (deleted) {
      setState(() {
        _selectedProfileId = SchoolScheduleSettings.normalProfileId;
      });
    } else {
      _message('لا يمكن حذف هذا الجدول الأساسي.');
    }
  }

  Future<void> _addPeriod(
    BuildContext context,
    String profileId,
  ) async {
    final value = await widget.controller.addSchoolPeriod(profileId);
    if (!mounted) return;

    if (value == null) {
      _message('تعذر إضافة فترة جديدة بعد نهاية اليوم.');
      return;
    }

    await _editPeriod(context, profileId, value);
  }

  Future<void> _editPeriod(
    BuildContext context,
    String profileId,
    SchoolPeriod period,
  ) async {
    final result = await showModalBottomSheet<SchoolPeriod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PeriodEditorSheet(period: period),
    );

    if (result == null) return;

    final saved = await widget.controller.updateSchoolPeriod(
      profileId,
      result,
    );
    if (!mounted || saved) return;

    _message(
      'تعذر حفظ الفترة: تأكد من عدم تداخلها مع فترة أخرى ومن أن نهايتها لا تتجاوز منتصف الليل.',
    );
  }

  Future<void> _deletePeriod(
    BuildContext context,
    String profileId,
    SchoolPeriod period,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الفترة؟'),
        content: Text(
          'سيتم حذف «${period.name}» من هذا الجدول. أي حصة مدرس مرتبطة بها ستبقى محفوظة لكنها تصبح غير فعالة حتى يعود لها وقت صالح.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await widget.controller.removeSchoolPeriod(profileId, period.id);
  }

  Future<String?> _askForName(
    BuildContext context, {
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.pop(dialogContext, value);
            }
          },
          decoration: const InputDecoration(
            labelText: 'اسم الجدول',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة الجداول الافتراضية؟'),
        content: const Text(
          'سيتم حذف الجداول المخصصة وإرجاع الدوام العادي ودوام رمضان وتوزيع أيام الأسبوع إلى القيم الأصلية. حصص المدرس نفسها لن تُحذف، لكن الحصص التي لا يوجد لها وقت صالح ستصبح غير فعالة.',
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

    if (confirmed == true) {
      await widget.controller.resetSchoolSchedule();
      if (!mounted) return;
      setState(() {
        _selectedProfileId = SchoolScheduleSettings.normalProfileId;
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _RamadanCard extends StatelessWidget {
  const _RamadanCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: enabled,
        onChanged: onChanged,
        secondary: CircleAvatar(
          backgroundColor: enabled
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.nightlight_round,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: const Text(
          'دوام رمضان',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'يستبدل الدوام العادي بجدول رمضان فقط؛ الجداول المخصصة تبقى كما عيّنتها.',
        ),
      ),
    );
  }
}

class _WeekdayMapCard extends StatelessWidget {
  const _WeekdayMapCard({
    required this.schedule,
    required this.days,
    required this.onChanged,
  });

  final SchoolScheduleSettings schedule;
  final List<(int, String)> days;
  final Future<void> Function(int weekday, String profileId) onChanged;

  @override
  Widget build(BuildContext context) {
    final profiles = schedule.profiles.values.toList(growable: false)
      ..sort((a, b) => _profileOrder(a.id).compareTo(_profileOrder(b.id)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جدول أيام الأسبوع',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'اختر جدولًا مختلفًا لكل يوم أو اجعله إجازة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ...days.map((day) {
              final stored = schedule.weekdayMap[day.$1] ??
                  SchoolScheduleSettings.offProfileId;
              final safeStored = stored == SchoolScheduleSettings.offProfileId ||
                      schedule.profiles.containsKey(stored)
                  ? stored
                  : SchoolScheduleSettings.offProfileId;
              final effective = schedule.effectiveProfileIdForWeekday(day.$1);
              final ramadanApplied = schedule.ramadanMode &&
                  safeStored == SchoolScheduleSettings.normalProfileId &&
                  effective == SchoolScheduleSettings.ramadanProfileId;

              return Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 86,
                        child: Text(
                          day.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: safeStored,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: SchoolScheduleSettings.offProfileId,
                              child: Text('إجازة'),
                            ),
                            ...profiles.map(
                              (profile) => DropdownMenuItem(
                                value: profile.id,
                                child: Text(profile.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              onChanged(day.$1, value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (ramadanApplied)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'يُطبق جدول رمضان حاليًا',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (day != days.last) const Divider(height: 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  static int _profileOrder(String id) {
    if (id == SchoolScheduleSettings.normalProfileId) return 0;
    if (id == SchoolScheduleSettings.ramadanProfileId) return 1;
    return 10;
  }
}

class _ProfileManagerCard extends StatelessWidget {
  const _ProfileManagerCard({
    required this.selectedProfileId,
    required this.profile,
    required this.profiles,
    required this.builtIn,
    required this.onProfileChanged,
    required this.onCreateBlank,
    required this.onDuplicate,
    required this.onRename,
    required this.onDeleteProfile,
    required this.onAddPeriod,
    required this.onEditPeriod,
    required this.onDeletePeriod,
  });

  final String selectedProfileId;
  final SchoolScheduleProfile profile;
  final Map<String, SchoolScheduleProfile> profiles;
  final bool builtIn;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onCreateBlank;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onDeleteProfile;
  final VoidCallback onAddPeriod;
  final ValueChanged<SchoolPeriod> onEditPeriod;
  final ValueChanged<SchoolPeriod> onDeletePeriod;

  @override
  Widget build(BuildContext context) {
    final entries = profiles.values.toList(growable: false)
      ..sort((a, b) => _order(a.id).compareTo(_order(b.id)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إدارة الجداول',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'عدّل الجدول الحالي أو أنشئ جدولًا مستقلًا لأيام خاصة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: selectedProfileId,
              decoration: const InputDecoration(
                labelText: 'الجدول الذي تريد تعديله',
                border: OutlineInputBorder(),
              ),
              items: entries
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onProfileChanged(value);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onCreateBlank,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('جدول جديد'),
                ),
                OutlinedButton.icon(
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ الحالي'),
                ),
                OutlinedButton.icon(
                  onPressed: builtIn ? null : onRename,
                  icon: const Icon(Icons.drive_file_rename_outline_rounded),
                  label: const Text('إعادة تسمية'),
                ),
                OutlinedButton.icon(
                  onPressed: builtIn ? null : onDeleteProfile,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف الجدول'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${profile.periods.length} فترة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (profile.periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'هذا الجدول فارغ. أضف أول فترة للبدء.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...profile.periods.map(
                (period) => _PeriodRow(
                  period: period,
                  onEdit: () => onEditPeriod(period),
                  onDelete: () => onDeletePeriod(period),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onAddPeriod,
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('إضافة فترة'),
            ),
          ],
        ),
      ),
    );
  }

  static int _order(String id) {
    if (id == SchoolScheduleSettings.normalProfileId) return 0;
    if (id == SchoolScheduleSettings.ramadanProfileId) return 1;
    return 10;
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolPeriod period;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: period.teacherSelectable
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          period.teacherSelectable
              ? Icons.school_outlined
              : period.id == 'break'
                  ? Icons.free_breakfast_outlined
                  : Icons.groups_outlined,
          color: period.teacherSelectable
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        period.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${ArabicFormat.minutesClock(period.startMinutes)} – ${ArabicFormat.minutesClock(period.endMinutes)} • ${period.durationMinutes} دقيقة',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            tooltip: 'تعديل الفترة',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'حذف الفترة',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _PeriodEditorSheet extends StatefulWidget {
  const _PeriodEditorSheet({required this.period});

  final SchoolPeriod period;

  @override
  State<_PeriodEditorSheet> createState() => _PeriodEditorSheetState();
}

class _PeriodEditorSheetState extends State<_PeriodEditorSheet> {
  late final TextEditingController _nameController;
  late TimeOfDay _start;
  late int _duration;

  static const _durations = <int>[
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
    75,
    90,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.period.name);
    _start = TimeOfDay(
      hour: widget.period.startMinutes ~/ 60,
      minute: widget.period.startMinutes % 60,
    );
    _duration = widget.period.durationMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationOptions = <int>{..._durations, _duration}.toList()
      ..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        6,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تعديل الفترة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'اسم الفترة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('وقت البداية'),
              subtitle: Text(
                ArabicFormat.minutesClock(_start.hour * 60 + _start.minute),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(
                labelText: 'مدة الفترة',
                border: OutlineInputBorder(),
              ),
              items: durationOptions
                  .map(
                    (value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value دقيقة'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _duration = value);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ الفترة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _start,
      helpText: 'وقت بداية الفترة',
    );
    if (value != null && mounted) {
      setState(() => _start = value);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الفترة أولًا.')),
      );
      return;
    }

    Navigator.pop(
      context,
      widget.period.copyWith(
        name: name,
        startMinutes: _start.hour * 60 + _start.minute,
        durationMinutes: _duration,
      ),
    );
  }
}
