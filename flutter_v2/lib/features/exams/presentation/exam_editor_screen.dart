import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:math_keyboard/math_keyboard.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/exam.dart';
import '../../../core/models/exam_content_block.dart';
import '../../../core/models/exam_paper_template.dart';
import '../../../core/storage/exam_store.dart';
import 'exam_paper_preview_screen.dart';

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
  late ExamPaperTemplate _template;
  int? _weekday;
  String? _periodId;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _className = TextEditingController(text: e?.className ?? '');
    _duration = TextEditingController(
      text: (e?.durationMinutes ?? 60).toString(),
    );
    _questions = List<ExamQuestion>.from(
      e?.questions ?? const <ExamQuestion>[],
    );
    _template = e?.template ?? const ExamPaperTemplate();
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
        const SnackBar(content: Text('أدخل عنوان الاختبار والمادة أولاً.')),
      );
      return;
    }

    final now = DateTime.now();
    final old = widget.initial;
    final exam = Exam(
      id: old?.id ?? 'exam_' + now.microsecondsSinceEpoch.toString(),
      title: title,
      subject: subject,
      className: _className.text.trim(),
      weekday: _weekday,
      periodId: _periodId,
      durationMinutes: int.tryParse(_duration.text) ?? 60,
      template: _template,
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
    final q = await showModalBottomSheet<ExamQuestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _QuestionEditorSheet(),
    );
    if (q != null) setState(() => _questions.add(q));
  }

  Future<void> _editQuestion(int index) async {
    final q = await showModalBottomSheet<ExamQuestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _QuestionEditorSheet(initial: _questions[index]),
    );
    if (q != null) setState(() => _questions[index] = q);
  }

  Future<void> _editTemplate() async {
    final t = await showModalBottomSheet<ExamPaperTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PaperTemplateSheet(initial: _template),
    );
    if (t != null) setState(() => _template = t);
  }

  Exam _draftExam() {
    final now = DateTime.now();
    return Exam(
      id: widget.initial?.id ?? 'draft_exam',
      title: _title.text.trim().isEmpty ? 'اختبار جديد' : _title.text.trim(),
      subject: _subject.text.trim(),
      className: _className.text.trim(),
      weekday: _weekday,
      periodId: _periodId,
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 60,
      template: _template,
      questions: List.unmodifiable(_questions),
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _previewPaper() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamPaperPreviewScreen(exam: _draftExam()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.controller.teacherPeriodCatalog;
    final totalMarks = _questions.fold<double>(0, (sum, q) => sum + q.marks);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'اختبار جديد' : 'تعديل الاختبار'),
        actions: [
          IconButton(
            tooltip: 'معاينة A4',
            onPressed: _previewPaper,
            icon: const Icon(Icons.preview_outlined),
          ),
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
        children: [
          _CardSection(
            title: 'بيانات الاختبار',
            icon: Icons.assignment_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _title,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الاختبار',
                          hintText: 'مثال: اختبار الشهر الأول',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الزمن',
                          suffixText: 'د',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subject,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(labelText: 'المادة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _className,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'الصف / الشعبة',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _weekday,
                        decoration: const InputDecoration(labelText: 'اليوم'),
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
                        onChanged: (value) =>
                            setState(() => _weekday = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: periods.any((p) => p.id == _periodId)
                            ? _periodId
                            : null,
                        decoration: const InputDecoration(labelText: 'الحصة'),
                        items: [
                          for (final p in periods)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                        ],
                        onChanged: _weekday == null
                            ? null
                            : (value) =>
                                setState(() => _periodId = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CardSection(
            title: 'ورقة الاختبار',
            icon: Icons.article_outlined,
            trailing: TextButton.icon(
              onPressed: _editTemplate,
              icon: const Icon(Icons.tune),
              label: const Text('إعدادات الورقة'),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _template.examTitle.isEmpty
                        ? 'قالب الاختبار القياسي'
                        : _template.examTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _template.schoolName +
                        '  •  ' +
                        _template.subjectLabel +
                        ': ' +
                        (_subject.text.trim().isEmpty
                            ? '—'
                            : _subject.text.trim()),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _template.instruction,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CardSection(
            title: 'الأسئلة',
            icon: Icons.quiz_outlined,
            trailing: Text(
              _questions.length.toString() +
                  ' سؤال • ' +
                  _formatMarks(totalMarks) +
                  ' درجة',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            child: Column(
              children: [
                if (_questions.isEmpty)
                  const _EmptyQuestions()
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _questions.removeAt(oldIndex);
                        _questions.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      return _QuestionCard(
                        key: ValueKey(q.id),
                        number: index + 1,
                        question: q,
                        onEdit: () => _editQuestion(index),
                        onDelete: () =>
                            setState(() => _questions.removeAt(index)),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة سؤال'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: FilledButton.icon(
          onPressed: _previewPaper,
          icon: const Icon(Icons.description_outlined),
          label: const Text('معاينة ورقة الاختبار A4'),
        ),
      ),
    );
  }

  static String _formatMarks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
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

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyQuestions extends StatelessWidget {
  const _EmptyQuestions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.quiz_outlined, size: 42),
          SizedBox(height: 8),
          Text(
            'لم تتم إضافة أسئلة بعد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'اضغط «إضافة سؤال» وابدأ الكتابة مباشرة.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required super.key,
    required this.number,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  final int number;
  final ExamQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final equations = question.effectiveContent
        .where((b) => b.type == ExamContentBlockType.equation)
        .length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(number.toString())),
        title: Text(
          _questionTitle(question),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
        ),
        subtitle: Text(
          question.type.label +
              '  •  ' +
              _formatMarks(question.marks) +
              ' درجة' +
              (equations == 0
                  ? ''
                  : '  •  ' + equations.toString() + ' معادلة'),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  static String _questionTitle(ExamQuestion q) {
    for (final block in q.effectiveContent) {
      if (block.type == ExamContentBlockType.text &&
          block.value.trim().isNotEmpty) {
        return block.value.trim();
      }
    }
    return 'سؤال يحتوي على معادلة';
  }

  static String _formatMarks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _QuestionEditorSheet extends StatefulWidget {
  const _QuestionEditorSheet({this.initial});

  final ExamQuestion? initial;

  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  late ExamQuestionType _type;
  late final TextEditingController _prompt;
  late final TextEditingController _answer;
  late final TextEditingController _marks;
  late List<TextEditingController> _options;
  late List<ExamContentBlock> _equations;
  int? _correct;
  final FocusNode _promptFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.multipleChoice;
    _answer = TextEditingController(text: q?.answer ?? '');
    _marks = TextEditingController(text: (q?.marks ?? 1).toString());

    final textParts = <String>[];
    final equations = <ExamContentBlock>[];
    for (final block
        in q?.effectiveContent ?? const <ExamContentBlock>[]) {
      if (block.type == ExamContentBlockType.text) {
        if (block.value.trim().isNotEmpty) textParts.add(block.value);
      } else {
        equations.add(block);
      }
    }
    _prompt = TextEditingController(text: textParts.join('\n'));
    _equations = equations;

    final optionTexts = q?.options.isNotEmpty == true
        ? q!.options
        : const <String>[
            'الخيار الأول',
            'الخيار الثاني',
            'الخيار الثالث',
            'الخيار الرابع',
          ];
    _options = [
      for (final value in optionTexts) TextEditingController(text: value),
    ];
    _correct = q?.correctOptionIndex;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    _marks.dispose();
    _promptFocus.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addEquation() async {
    final latex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _EquationSheet(initial: ''),
    );
    if (latex == null || latex.trim().isEmpty) return;
    setState(() => _equations.add(ExamContentBlock.equation(latex.trim())));
  }

  Future<void> _editEquation(int index) async {
    final latex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EquationSheet(initial: _equations[index].value),
    );
    if (latex == null || latex.trim().isEmpty) return;
    setState(
      () => _equations[index] = ExamContentBlock.equation(latex.trim()),
    );
  }

  void _insertText(String value) {
    final start =
        _prompt.selection.start < 0 ? _prompt.text.length : _prompt.selection.start;
    final end = _prompt.selection.end < 0 ? start : _prompt.selection.end;
    _prompt.value = _prompt.value.copyWith(
      text: _prompt.text.substring(0, start) +
          value +
          _prompt.text.substring(end),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _promptFocus.requestFocus();
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final removed = _options.removeAt(index);
    removed.dispose();
    if (_correct == index) {
      _correct = null;
    } else if (_correct != null && _correct! > index) {
      _correct = _correct! - 1;
    }
    setState(() {});
  }

  void _save() {
    final prompt = _prompt.text.trim();
    final marks = double.tryParse(_marks.text.trim()) ?? 1;

    if (prompt.isEmpty && _equations.isEmpty) {
      _error('اكتب نص السؤال أو أضف معادلة.');
      return;
    }
    if (marks <= 0) {
      _error('يجب أن تكون درجة السؤال أكبر من صفر.');
      return;
    }

    final options = _type == ExamQuestionType.multipleChoice
        ? _options.map((c) => c.text.trim()).toList()
        : <String>[];

    if (_type == ExamQuestionType.multipleChoice) {
      if (options.where((x) => x.isNotEmpty).length < 2) {
        _error('أدخل خيارين على الأقل.');
        return;
      }
      if (_correct == null || _correct! >= options.length) {
        _error('حدد الإجابة الصحيحة.');
        return;
      }
    }

    final content = <ExamContentBlock>[];
    if (prompt.isNotEmpty) content.add(ExamContentBlock.text(prompt));
    content.addAll(_equations);

    Navigator.pop(
      context,
      ExamQuestion(
        id: widget.initial?.id ??
            'question_' + DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        prompt: prompt,
        content: List.unmodifiable(content),
        options: options,
        correctOptionIndex:
            _type == ExamQuestionType.multipleChoice ? _correct : null,
        answer: _answer.text.trim(),
        marks: marks,
      ),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChoice = _type == ExamQuestionType.multipleChoice;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.initial == null ? 'إضافة سؤال' : 'تعديل السؤال',
              ),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('حفظ'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              children: [
                _QuestionTypeSelector(
                  value: _type,
                  onChanged: (value) => setState(() => _type = value),
                ),
                const SizedBox(height: 10),
                _EditorCard(
                  title: 'نص السؤال',
                  icon: Icons.edit_note_outlined,
                  child: Column(
                    children: [
                      TextField(
                        controller: _prompt,
                        focusNode: _promptFocus,
                        textDirection: TextDirection.rtl,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: 'اكتب السؤال هنا...',
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 1),
                      _ScientificToolbar(
                        onText: _insertText,
                        onEquation: _addEquation,
                      ),
                    ],
                  ),
                ),
                if (_equations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _EditorCard(
                    title: 'المعادلات',
                    icon: Icons.functions,
                    child: Column(
                      children: [
                        for (var i = 0; i < _equations.length; i++)
                          _EquationTile(
                            latex: _equations[i].value,
                            onEdit: () => _editEquation(i),
                            onDelete: () =>
                                setState(() => _equations.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (isChoice)
                  _EditorCard(
                    title: 'خيارات الإجابة',
                    icon: Icons.radio_button_checked,
                    child: Column(
                      children: [
                        for (var i = 0; i < _options.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: i,
                                  groupValue: _correct,
                                  onChanged: (value) =>
                                      setState(() => _correct = value),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _options[i],
                                    textDirection: TextDirection.rtl,
                                    decoration: InputDecoration(
                                      labelText: 'الخيار ' + _letter(i),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: _options.length <= 2
                                      ? null
                                      : () => _removeOption(i),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed:
                                _options.length >= 6 ? null : _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة خيار'),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'اضغط الدائرة بجانب الخيار لتحديد الإجابة الصحيحة.',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _EditorCard(
                    title: 'الإجابة النموذجية',
                    icon: Icons.check_circle_outline,
                    child: TextField(
                      controller: _answer,
                      textDirection: TextDirection.rtl,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'اختياري — للحفظ والتصحيح لاحقًا.',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _EditorCard(
                  title: 'درجة السؤال',
                  icon: Icons.grade_outlined,
                  child: TextField(
                    controller: _marks,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الدرجة',
                      suffixText: 'درجة',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ السؤال'),
                ),
              ],
            ),
          ),
        ),
    );
  }

  static String _letter(int index) {
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    return index < letters.length ? letters[index] : (index + 1).toString();
  }
}

class _QuestionTypeSelector extends StatelessWidget {
  const _QuestionTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final ExamQuestionType value;
  final ValueChanged<ExamQuestionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      title: 'نوع السؤال',
      icon: Icons.category_outlined,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final type in ExamQuestionType.values)
            ChoiceChip(
              label: Text(type.label),
              selected: value == type,
              onSelected: (_) => onChanged(type),
            ),
        ],
      ),
    );
  }
}

class _ScientificToolbar extends StatelessWidget {
  const _ScientificToolbar({
    required this.onText,
    required this.onEquation,
  });

  final ValueChanged<String> onText;
  final VoidCallback onEquation;

  static const groups = <List<String>>[
    ['²', '³', 'ⁿ', '₁', '₂', 'ₙ', '½', '¼', '¾'],
    ['√', 'π', '∞', '±', '≤', '≥', '≠', '≈', 'Δ'],
    ['α', 'β', 'γ', 'θ', 'λ', 'μ', 'ρ', 'σ', 'Ω'],
    ['+', '−', '×', '÷', '=', '%', '°', '∑', '∫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'رموز الرياضيات والفيزياء',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onEquation,
                icon: const Icon(Icons.functions, size: 18),
                label: const Text('معادلة'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final symbol in group)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: OutlinedButton(
                          onPressed: () => onText(symbol),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(40, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text(
                            symbol,
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Text(
            'الكسور والجذور والأسس المركبة تُنشأ من زر «معادلة».',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EquationTile extends StatelessWidget {
  const _EquationTile({
    required this.latex,
    required this.onEdit,
    required this.onDelete,
  });

  final String latex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                latex,
                mathStyle: MathStyle.display,
                onErrorFallback: (_) => const Text('معادلة غير صالحة'),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تحرير',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'حذف',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EquationSheet extends StatefulWidget {
  const _EquationSheet({required this.initial});

  final String initial;

  @override
  State<_EquationSheet> createState() => _EquationSheetState();
}

class _EquationSheetState extends State<_EquationSheet> {
  late final MathFieldEditingController _controller;
  late String _latex;

  static const symbols = <String, String>{
    'كسر': r'\frac{}{}',
    'جذر': r'\sqrt{}',
    'أس': r'^{ }',
    'مؤشر': r'_{ }',
    'π': r'\pi',
    '∞': r'\infty',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'θ': r'\theta',
    'λ': r'\lambda',
    'μ': r'\mu',
    'ρ': r'\rho',
    'Ω': r'\Omega',
    '≤': r'\le',
    '≥': r'\ge',
    '≠': r'\ne',
    '≈': r'\approx',
    '±': r'\pm',
    '×': r'\times',
    '÷': r'\div',
    'Δ': r'\Delta',
    'Σ': r'\Sigma',
    '∫': r'\int',
  };

  @override
  void initState() {
    super.initState();
    _latex = widget.initial;
    _controller = MathFieldEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insert(String value) {
    _latex = _latex + ' ' + value + ' ';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Scaffold(
            appBar: AppBar(
              title: const Text('محرر المعادلات'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  onPressed: _latex.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, _latex.trim()),
                  icon: const Icon(Icons.check),
                  label: const Text('إدراج'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const Text(
                  'استخدم اللوحة للكسور والجذور والأسس والرموز العلمية.',
                ),
                const SizedBox(height: 10),
                MathField(
                  controller: _controller,
                  variables: const [
                    'a',
                    'b',
                    'c',
                    'x',
                    'y',
                    'z',
                    'm',
                    'v',
                    't',
                  ],
                  keyboardType: MathKeyboardType.expression,
                  decoration: const InputDecoration(
                    labelText: 'اكتب المعادلة هنا',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _latex = value;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in symbols.entries)
                      OutlinedButton(
                        onPressed: () => _insert(entry.value),
                        child: Text(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_latex.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Math.tex(
                      _latex,
                      mathStyle: MathStyle.display,
                      onErrorFallback: (_) =>
                          const Text('راجع صيغة المعادلة.'),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      ),
    );
  }
}

class _PaperTemplateSheet extends StatefulWidget {
  const _PaperTemplateSheet({required this.initial});

  final ExamPaperTemplate initial;

  @override
  State<_PaperTemplateSheet> createState() => _PaperTemplateSheetState();
}

class _PaperTemplateSheetState extends State<_PaperTemplateSheet> {
  late final TextEditingController _school;
  late final TextEditingController _title;
  late final TextEditingController _year;
  late final TextEditingController _instruction;
  late final TextEditingController _ministry;
  late final TextEditingController _office;
  late final TextEditingController _administration;
  late final TextEditingController _footerRight;
  late final TextEditingController _footerLeft;
  late bool _showMarks;
  late bool _showPageNumber;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _school = TextEditingController(text: t.schoolName);
    _title = TextEditingController(text: t.examTitle);
    _year = TextEditingController(text: t.academicYear);
    _instruction = TextEditingController(text: t.instruction);
    _ministry = TextEditingController(text: t.ministry);
    _office = TextEditingController(text: t.educationOffice);
    _administration = TextEditingController(text: t.educationAdministration);
    _footerRight = TextEditingController(text: t.footerRight);
    _footerLeft = TextEditingController(text: t.footerLeft);
    _showMarks = t.showQuestionMarks;
    _showPageNumber = t.showPageNumber;
  }

  @override
  void dispose() {
    for (final c in [
      _school,
      _title,
      _year,
      _instruction,
      _ministry,
      _office,
      _administration,
      _footerRight,
      _footerLeft,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Scaffold(
            appBar: AppBar(
              title: const Text('إعداد ورقة الاختبار'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('حفظ'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الكليشة الجاهزة تُستخدم تلقائيًا في ورقة A4. عدّل فقط البيانات التي تحتاجها.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _TemplateField(
                  controller: _school,
                  label: 'اسم المدرسة',
                  icon: Icons.school_outlined,
                ),
                _TemplateField(
                  controller: _title,
                  label: 'عنوان الاختبار في الكليشة',
                  icon: Icons.title,
                ),
                _TemplateField(
                  controller: _year,
                  label: 'العام الدراسي',
                  icon: Icons.calendar_month_outlined,
                ),
                _TemplateField(
                  controller: _instruction,
                  label: 'التعليمات',
                  icon: Icons.info_outline,
                  maxLines: 3,
                ),
                SwitchListTile.adaptive(
                  title: const Text('إظهار درجات الأسئلة'),
                  value: _showMarks,
                  onChanged: (value) =>
                      setState(() => _showMarks = value),
                ),
                SwitchListTile.adaptive(
                  title: const Text('إظهار رقم الصفحة'),
                  value: _showPageNumber,
                  onChanged: (value) =>
                      setState(() => _showPageNumber = value),
                ),
                ExpansionTile(
                  title: const Text('إعدادات الكليشة المتقدمة'),
                  childrenPadding: const EdgeInsets.only(bottom: 10),
                  children: [
                    _TemplateField(
                      controller: _ministry,
                      label: 'الجهة العليا',
                    ),
                    _TemplateField(
                      controller: _office,
                      label: 'مكتب التربية',
                    ),
                    _TemplateField(
                      controller: _administration,
                      label: 'إدارة التربية والتعليم',
                    ),
                    _TemplateField(
                      controller: _footerRight,
                      label: 'التذييل الأيمن',
                    ),
                    _TemplateField(
                      controller: _footerLeft,
                      label: 'التذييل الأيسر',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ إعدادات الورقة'),
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _save() {
    Navigator.pop(
      context,
      widget.initial.copyWith(
        ministry: _ministry.text.trim(),
        educationOffice: _office.text.trim(),
        educationAdministration: _administration.text.trim(),
        schoolName: _school.text.trim(),
        examTitle: _title.text.trim(),
        academicYear: _year.text.trim(),
        instruction: _instruction.text.trim(),
        footerRight: _footerRight.text.trim(),
        footerLeft: _footerLeft.text.trim(),
        showQuestionMarks: _showMarks,
        showPageNumber: _showPageNumber,
      ),
    );
  }
}

class _TemplateField extends StatelessWidget {
  const _TemplateField({
    required this.controller,
    required this.label,
    this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        textDirection: TextDirection.rtl,
        minLines: maxLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }
}
