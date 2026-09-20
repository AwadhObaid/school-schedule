import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/data/school_schedule_defaults.dart';
import '../../../core/models/school_period.dart';
import '../../../core/models/teacher_class.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_format.dart';

class MyClassesScreen extends StatelessWidget {
  const MyClassesScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text('حصصي', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'حدد الحصص التي تقوم بتدريسها. اضغط على أي خلية لإضافة المادة والصف أو تعديلهما.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _SummaryCard(count: controller.activeClassCount),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الجدول الأسبوعي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'الأخضر = لديك حصة',
                      style: TextStyle(color: AppTheme.primary),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _WeeklyGrid(
                        controller: controller,
                        onEdit: (day, period) =>
                            _openEditor(context, day, period),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الحصص تُحفظ على هذا الجهاز وتبقى مفعلة أسبوعيًا حتى تقوم بتعديلها أو حذفها.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    int weekday,
    SchoolPeriod period,
  ) async {
    final existing = controller.assignmentFor(weekday, period.id);
    final subjectController = TextEditingController(
      text: existing?.subject ?? '',
    );
    final classroomController = TextEditingController(
      text: existing?.classroom ?? '',
    );
    final notesController = TextEditingController(
      text: existing?.notes ?? '',
    );

    var enabled = existing?.enabled ?? true;

    final result = await showModalBottomSheet<_ClassEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${ArabicFormat.dayName(weekday)} • ${period.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ArabicFormat.minutesClock(period.startMinutes)} – ${ArabicFormat.minutesClock(period.endMinutes)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (value) =>
                          setSheetState(() => enabled = value),
                      title: const Text('لدي حصة في هذا الوقت'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subjectController,
                      enabled: enabled,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'المادة',
                        hintText: 'مثال: الرياضيات',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: classroomController,
                      enabled: enabled,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الصف / الشعبة',
                        hintText: 'مثال: الصف 8 / 2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      enabled: enabled,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة اختيارية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        if (!enabled) {
                          Navigator.pop(
                            sheetContext,
                            const _ClassEditorResult.delete(),
                          );
                          return;
                        }

                        final subject = subjectController.text.trim();
                        if (subject.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('اكتب اسم المادة أولًا.'),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(
                          sheetContext,
                          _ClassEditorResult.save(
                            TeacherClass(
                              weekday: weekday,
                              periodId: period.id,
                              subject: subject,
                              classroom:
                                  _nullIfEmpty(classroomController.text),
                              notes: _nullIfEmpty(notesController.text),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('حفظ الحصة'),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            const _ClassEditorResult.delete(),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('حذف هذه الحصة'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    subjectController.dispose();
    classroomController.dispose();
    notesController.dispose();

    if (result == null) return;

    if (result.delete) {
      await controller.removeTeacherClass(weekday, period.id);
      return;
    }

    final value = result.value;
    if (value != null) {
      await controller.upsertTeacherClass(value);
    }
  }

  static String? _nullIfEmpty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7EBDD)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.school_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 0
                  ? 'لم تحدد أي حصة بعد'
                  : 'لديك $count حصة أسبوعيًا',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGrid extends StatelessWidget {
  const _WeeklyGrid({
    required this.controller,
    required this.onEdit,
  });

  final AppController controller;
  final void Function(int weekday, SchoolPeriod period) onEdit;

  static const _days = <(int, String)>[
    (DateTime.sunday, 'الأحد'),
    (DateTime.monday, 'الاثنين'),
    (DateTime.tuesday, 'الثلاثاء'),
    (DateTime.wednesday, 'الأربعاء'),
    (DateTime.thursday, 'الخميس'),
  ];

  @override
  Widget build(BuildContext context) {
    const periods = SchoolScheduleDefaults.normalTeachingPeriods;

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 82),
            ...periods.map(
              (period) => SizedBox(
                width: 62,
                child: Center(
                  child: Text(
                    period.id.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._days.map((day) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  child: Text(
                    day.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ...periods.map((period) {
                  final assignment = controller.assignmentFor(
                    day.$1,
                    period.id,
                  );
                  final active = assignment != null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onEdit(day.$1, period),
                      child: Ink(
                        width: 56,
                        height: 58,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFDDF1E4)
                              : const Color(0xFFF3F5F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFB8DDC5)
                                : const Color(0xFFE6E9EA),
                          ),
                        ),
                        child: active
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: Text(
                                      assignment.subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.add_rounded,
                                color: Color(0xFF9AA3AD),
                              ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}


class _ClassEditorResult {
  const _ClassEditorResult.save(this.value) : delete = false;
  const _ClassEditorResult.delete()
      : value = null,
        delete = true;

  final TeacherClass? value;
  final bool delete;
}
