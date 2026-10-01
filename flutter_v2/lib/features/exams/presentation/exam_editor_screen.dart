import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/exam.dart';
import '../../../core/storage/exam_store.dart';

class ExamEditorScreen extends StatefulWidget {
  const ExamEditorScreen({
    required this.controller,
    required this.store,
    this.initial,
    super.key,
  });

  final AppController controller;
  final ExamStore store;
  final Exam? initial;

  @override
  State<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends State<ExamEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _className;
  late final TextEditingController _duration;
  late List<ExamQuestion> _questions;
  int? _weekday;
  String? _periodId;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _className = TextEditingController(text: e?.className ?? '');
    _duration = TextEditingController(text: (e?.durationMinutes ?? 60).toString());
    _questions = List<ExamQuestion>.from(e?.questions ?? const <ExamQuestion>[]);
    _weekday = e?.weekday;
    _periodId = e?.periodId;
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _className.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    if (title.isEmpty || subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنوان الاختبار والمادة.')),
      );
      return;
    }

    final now = DateTime.now();
    final old = widget.initial;
    final exam = Exam(
      id: old?.id ?? 'exam_${now.microsecondsSinceEpoch}',
      title: title,
      subject: subject,
      className: _className.text.trim(),
      weekday: _weekday,
      periodId: _periodId,
      durationMinutes: int.tryParse(_duration.text) ?? 60,
      questions: List.unmodifiable(_questions),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );

    final all = await widget.store.load();
    final index = all.indexWhere((item) => item.id == exam.id);
    if (index >= 0) {
      all[index] = exam;
    } else {
      all.add(exam);
    }
    await widget.store.save(all);

    if (mounted) Navigator.pop(context, exam);
  }

  Future<void> _addQuestion() async {
    final q = await showDialog<ExamQuestion>(
      context: context,
      builder: (_) => const _QuestionDialog(),
    );
    if (q != null) setState(() => _questions.add(q));
  }

  Future<void> _editQuestion(int index) async {
    final q = await showDialog<ExamQuestion>(
      context: context,
      builder: (_) => _QuestionDialog(initial: _questions[index]),
    );
    if (q != null) setState(() => _questions[index] = q);
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.controller.teacherPeriodCatalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'اختبار جديد' : 'تعديل الاختبار'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الاختبار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subject,
                    decoration: const InputDecoration(
                      labelText: 'المادة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _className,
                    decoration: const InputDecoration(
                      labelText: 'الصف / الشعبة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _weekday,
                    decoration: const InputDecoration(
                      labelText: 'اليوم المرتبط',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final day in [
                        DateTime.saturday,
                        DateTime.sunday,
                        DateTime.monday,
                        DateTime.tuesday,
                        DateTime.wednesday,
                        DateTime.thursday,
                        DateTime.friday,
                      ])
                        DropdownMenuItem(
                          value: day,
                          child: Text(_dayName(day)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _weekday = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: periods.any((p) => p.id == _periodId) ? _periodId : null,
                    decoration: const InputDecoration(
                      labelText: 'الحصة المرتبطة',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in periods)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                    ],
                    onChanged: _weekday == null
                        ? null
                        : (value) => setState(() => _periodId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة الاختبار بالدقائق',
                      border: OutlineInputBorder(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الأسئلة ${_questions.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _questions.length; i++)
                    ListTile(
                      leading: CircleAvatar(child: Text((i + 1).toString())),
                      title: Text(_questions[i].prompt),
                      subtitle: Text(
                        '${_questions[i].type.label} • ${_questions[i].marks} درجة',
                      ),
                      onTap: () => _editQuestion(i),
                      trailing: IconButton(
                        onPressed: () => setState(() => _questions.removeAt(i)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة سؤال'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayName(int day) {
    const names = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    return names[day] ?? '';
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.initial});
  final ExamQuestion? initial;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late ExamQuestionType _type;
  late final TextEditingController _prompt;
  late final TextEditingController _answer;
  late final TextEditingController _marks;
  late List<TextEditingController> _options;
  int? _correct;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.multipleChoice;
    _prompt = TextEditingController(text: q?.prompt ?? '');
    _answer = TextEditingController(text: q?.answer ?? '');
    _marks = TextEditingController(text: (q?.marks ?? 1).toString());
    final optionTexts = q?.options.isNotEmpty == true
        ? q!.options
        : const <String>[
            'الخيار الأول',
            'الخيار الثاني',
            'الخيار الثالث',
            'الخيار الرابع',
          ];
    _options = optionTexts
        .map<TextEditingController>(
          (text) => TextEditingController(text: text),
        )
        .toList();
    _correct = q?.correctOptionIndex;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    _marks.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChoice = _type == ExamQuestionType.multipleChoice;
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة سؤال' : 'تعديل السؤال'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ExamQuestionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع السؤال'),
              items: [
                for (final type in ExamQuestionType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'نص السؤال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (isChoice)
              RadioGroup<int>(
                groupValue: _correct,
                onChanged: (value) {
                  setState(() => _correct = value);
                },
                child: Column(
                  children: [
                    ...List.generate(
                      _options.length,
                      (i) => Row(
                        children: [
                          Radio<int>(
                            value: i,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _options[i],
                              decoration: InputDecoration(
                                labelText: 'الخيار ' + (i + 1).toString(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              TextField(
                controller: _answer,
                decoration: const InputDecoration(labelText: 'الإجابة النموذجية'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _marks,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الدرجة'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('حفظ السؤال'),
        ),
      ],
    );
  }

  void _save() {
    final prompt = _prompt.text.trim();
    final marks = double.tryParse(_marks.text.trim()) ?? 1;
    final options = _type == ExamQuestionType.multipleChoice
        ? _options.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList()
        : <String>[];

    if (prompt.isEmpty || marks <= 0) return;
    if (_type == ExamQuestionType.multipleChoice &&
        (options.length < 2 || _correct == null || _correct! >= options.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد خيارين على الأقل والإجابة الصحيحة.')),
      );
      return;
    }

    Navigator.pop(
      context,
      ExamQuestion(
        id: widget.initial?.id ?? 'question_${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        prompt: prompt,
        options: options,
        correctOptionIndex: _type == ExamQuestionType.multipleChoice ? _correct : null,
        answer: _answer.text.trim(),
        marks: marks,
      ),
    );
  }
}
