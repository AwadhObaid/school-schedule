import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/school_period.dart';
import '../../../core/models/school_schedule_settings.dart';
import '../../../core/theme/app_theme.dart';
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
        final selectedProfile =
            schedule.profiles[_selectedProfileId] ??
            schedule.profiles[SchoolScheduleSettings.normalProfileId];

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'الجدول المدرسي',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'اضبط أوقات المدرسة هنا مرة واحدة. «حصصي» والتنبيهات تتبع هذه الأوقات تلقائيًا.',
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
              _ProfileEditorCard(
                selectedProfileId: _selectedProfileId,
                profile: selectedProfile,
                onProfileChanged: (value) {
                  setState(() => _selectedProfileId = value);
                },
                onEditPeriod: (period) =>
                    _editPeriod(context, selectedProfile.id, period),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _confirmReset(context),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('استعادة أوقات الجدول الافتراضية'),
            ),
          ],
        );
      },
    );
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
    await widget.controller.updateSchoolPeriod(profileId, result);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة الجدول الافتراضي؟'),
        content: const Text(
          'سيتم إرجاع أوقات الدوام العادي ودوام رمضان وتوزيع أيام الأسبوع إلى القيم الأصلية. حصص المدرس نفسها لن تُحذف.',
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
    }
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
              ? const Color(0xFFE6F4EB)
              : const Color(0xFFF1F3F4),
          child: Icon(
            Icons.nightlight_round,
            color: enabled ? AppTheme.primary : Colors.grey,
          ),
        ),
        title: const Text(
          'دوام رمضان',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'عند تفعيله تُستخدم أوقات رمضان تلقائيًا للأيام المضبوطة على الدوام العادي.',
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
              'حدد هل اليوم دوام أم إجازة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ...days.map((day) {
              final stored = schedule.weekdayMap[day.$1] ??
                  SchoolScheduleSettings.offProfileId;
              final effective = schedule.effectiveProfileIdForWeekday(day.$1);
              final ramadanApplied = schedule.ramadanMode &&
                  stored == SchoolScheduleSettings.normalProfileId &&
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
                          initialValue: stored,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: SchoolScheduleSettings.normalProfileId,
                              child: Text('دوام'),
                            ),
                            DropdownMenuItem(
                              value: SchoolScheduleSettings.offProfileId,
                              child: Text('إجازة'),
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
                    const Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'يُطبق جدول رمضان حاليًا',
                          style: TextStyle(
                            color: AppTheme.primary,
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
}

class _ProfileEditorCard extends StatelessWidget {
  const _ProfileEditorCard({
    required this.selectedProfileId,
    required this.profile,
    required this.onProfileChanged,
    required this.onEditPeriod,
  });

  final String selectedProfileId;
  final SchoolScheduleProfile profile;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<SchoolPeriod> onEditPeriod;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أوقات الدوام',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: SchoolScheduleSettings.normalProfileId,
                  label: Text('العادي'),
                  icon: Icon(Icons.wb_sunny_outlined),
                ),
                ButtonSegment(
                  value: SchoolScheduleSettings.ramadanProfileId,
                  label: Text('رمضان'),
                  icon: Icon(Icons.nightlight_outlined),
                ),
              ],
              selected: <String>{selectedProfileId},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onProfileChanged(selection.first);
                }
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6EE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                profile.name,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...profile.periods.map(
              (period) => _PeriodRow(
                period: period,
                onEdit: () => onEditPeriod(period),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.onEdit,
  });

  final SchoolPeriod period;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: period.teacherSelectable
            ? const Color(0xFFE6F4EB)
            : const Color(0xFFF1F3F4),
        child: Icon(
          period.teacherSelectable
              ? Icons.school_outlined
              : period.id == 'break'
                  ? Icons.free_breakfast_outlined
                  : Icons.groups_outlined,
          color: period.teacherSelectable ? AppTheme.primary : Colors.grey,
        ),
      ),
      title: Text(
        period.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${ArabicFormat.minutesClock(period.startMinutes)} – ${ArabicFormat.minutesClock(period.endMinutes)} • ${period.durationMinutes} دقيقة',
      ),
      trailing: IconButton(
        onPressed: onEdit,
        tooltip: 'تعديل الوقت',
        icon: const Icon(Icons.edit_outlined),
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
  late TimeOfDay _start;
  late int _duration;

  static const _durations = <int>[
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
  ];

  @override
  void initState() {
    super.initState();
    _start = TimeOfDay(
      hour: widget.period.startMinutes ~/ 60,
      minute: widget.period.startMinutes % 60,
    );
    _duration = widget.period.durationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final durationOptions = <int>{..._durations, _duration}.toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.period.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
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
            onPressed: () {
              Navigator.pop(
                context,
                widget.period.copyWith(
                  startMinutes: _start.hour * 60 + _start.minute,
                  durationMinutes: _duration,
                ),
              );
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ الوقت'),
          ),
        ],
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
}
