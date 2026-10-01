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

  Future<void> _editTemplate() async {
    final template = await showDialog<ExamPaperTemplate>(
      context: context,
      builder: (_) => _PaperTemplateDialog(initial: _template),
    );
    if (template != null) {
      setState(() => _template = template);
    }
  }

  Exam _draftExam() {
    final now = DateTime.now();
    final duration = int.tryParse(_duration.text.trim()) ?? 60;

    return Exam(
      id: widget.initial?.id ?? 'draft_exam',
      title: _title.text.trim().isEmpty ? 'اختبار جديد' : _title.text.trim(),
      subject: _subject.text.trim(),
      className: _className.text.trim(),
      weekday: _weekday,
      periodId: _periodId,
      durationMinutes: duration > 0 ? duration : 60,
      template: _template,
      questions: List.unmodifiable(_questions),
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _previewPaper() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamPaperPreviewScreen(
          exam: _draftExam(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.controller.teacherPeriodCatalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'اختبار جديد' : 'تعديل الاختبار'),
        actions: [
          IconButton(
            tooltip: 'معاينة ورقة A4',
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
                    initialValue: periods.any((p) => p.id == _periodId)
                        ? _periodId
                        : null,
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
                  Row(
                    children: [
                      const Icon(Icons.article_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'كليشة ورقة الاختبار',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _editTemplate,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تخصيص'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _template.examTitle.isEmpty
                        ? 'قالب A4 القياسي'
                        : _template.examTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_template.schoolName} • ${_template.subjectLabel}: ${_subject.text.isEmpty ? '—' : _subject.text}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _template.instruction,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'التنسيق محفوظ كقالب قابل للتخصيص، وسيُستخدم لاحقًا في معاينة A4 والتصدير.',
                    style: TextStyle(fontSize: 12),
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
                  Row(
                    children: [
                      const Icon(Icons.functions_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الأسئلة والمحرر العلمي',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${_questions.length} سؤال',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_questions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'ابدأ بإضافة سؤال. يمكنك الآن إضافة نصوص ومعادلات رياضية وفيزيائية داخل محتوى السؤال.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (var i = 0; i < _questions.length; i++)
                    ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: _QuestionSummary(question: _questions[i]),
                      subtitle: Text(
                        '${_questions[i].type.label} • ${_questions[i].marks} درجة • ${_questions[i].effectiveContent.where((item) => item.type == ExamContentBlockType.equation).length} معادلة',
                      ),
                      onTap: () => _editQuestion(i),
                      trailing: IconButton(
                        onPressed: () =>
                            setState(() => _questions.removeAt(i)),
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

class _QuestionSummary extends StatelessWidget {
  const _QuestionSummary({required this.question});

  final ExamQuestion question;

  @override
  Widget build(BuildContext context) {
    final blocks = question.effectiveContent;
    if (blocks.length == 1 && blocks.first.type == ExamContentBlockType.text) {
      return Text(blocks.first.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          if (block.type == ExamContentBlockType.text)
            Text(block.value)
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Math.tex(
                block.value,
                mathStyle: MathStyle.text,
                onErrorFallback: (_) =>
                    const Text('معادلة غير صالحة'),
              ),
            ),
      ],
    );
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
  late final TextEditingController _answer;
  late final TextEditingController _marks;
  late List<TextEditingController> _options;
  late List<ExamContentBlock> _content;
  int? _correct;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.multipleChoice;
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

    _content = List<ExamContentBlock>.from(
      q?.effectiveContent ?? const <ExamContentBlock>[],
    );
    if (_content.isEmpty) {
      _content = <ExamContentBlock>[const ExamContentBlock.text('')];
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _marks.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addEquation({int? index}) async {
    final latex = await showDialog<String>(
      context: context,
      builder: (_) => _EquationDialog(
        initial: index == null ? '' : _content[index].value,
      ),
    );
    if (latex == null || latex.trim().isEmpty) return;

    setState(() {
      final block = ExamContentBlock.equation(latex.trim());
      if (index == null) {
        _content.add(block);
      } else {
        _content[index] = block;
      }
    });
  }

  void _addText() {
    setState(() => _content.add(const ExamContentBlock.text('')));
  }

  void _moveBlock(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _content.length) return;
    setState(() {
      final item = _content.removeAt(index);
      _content.insert(target, item);
    });
  }

  void _removeBlock(int index) {
    if (_content.length == 1) return;
    setState(() => _content.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isChoice = _type == ExamQuestionType.multipleChoice;

    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة سؤال' : 'تعديل السؤال'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ExamQuestionType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'نوع السؤال'),
                items: [
                  for (final type in ExamQuestionType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'محتوى السؤال',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (var i = 0; i < _content.length; i++)
                      _ContentBlockEditor(
                        key: ValueKey('${i}_${_content[i].type}_${_content[i].value.hashCode}'),
                        block: _content[i],
                        index: i,
                        total: _content.length,
                        onTextChanged: (value) {
                          if (_content[i].type == ExamContentBlockType.text) {
                            _content[i] = ExamContentBlock.text(value);
                          }
                        },
                        onEditEquation: () => _addEquation(index: i),
                        onMoveUp: () => _moveBlock(i, -1),
                        onMoveDown: () => _moveBlock(i, 1),
                        onRemove: () => _removeBlock(i),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addText,
                          icon: const Icon(Icons.text_fields),
                          label: const Text('إضافة نص'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _addEquation(),
                          icon: const Icon(Icons.functions),
                          label: const Text('إضافة معادلة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isChoice)
                RadioGroup<int>(
                  groupValue: _correct,
                  onChanged: (value) {
                    setState(() => _correct = value);
                  },
                  child: Column(
                    children: [
                      for (var i = 0; i < _options.length; i++)
                        Row(
                          children: [
                            Radio<int>(value: i),
                            Expanded(
                              child: TextField(
                                controller: _options[i],
                                decoration: InputDecoration(
                                  labelText: 'الخيار ${i + 1}',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                )
              else
                TextField(
                  controller: _answer,
                  decoration: const InputDecoration(
                    labelText: 'الإجابة النموذجية',
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _marks,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الدرجة'),
              ),
            ],
          ),
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
    final content = _content
        .where((block) => block.value.trim().isNotEmpty)
        .toList(growable: false);
    final prompt = content
        .where((block) => block.type == ExamContentBlockType.text)
        .map((block) => block.value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');

    final marks = double.tryParse(_marks.text.trim()) ?? 1;
    final options = _type == ExamQuestionType.multipleChoice
        ? _options
            .map((c) => c.text.trim())
            .where((x) => x.isNotEmpty)
            .toList()
        : <String>[];

    if (content.isEmpty || marks <= 0) return;
    if (_type == ExamQuestionType.multipleChoice &&
        (options.length < 2 ||
            _correct == null ||
            _correct! >= options.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد خيارين على الأقل والإجابة الصحيحة.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      ExamQuestion(
        id: widget.initial?.id ??
            'question_${DateTime.now().microsecondsSinceEpoch}',
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
}

class _ContentBlockEditor extends StatefulWidget {
  const _ContentBlockEditor({
    required this.block,
    required this.index,
    required this.total,
    required this.onTextChanged,
    required this.onEditEquation,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    super.key,
  });

  final ExamContentBlock block;
  final int index;
  final int total;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onEditEquation;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  State<_ContentBlockEditor> createState() => _ContentBlockEditorState();
}

class _ContentBlockEditorState extends State<_ContentBlockEditor> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: widget.block.type == ExamContentBlockType.text
          ? widget.block.value
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ContentBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.type == ExamContentBlockType.text &&
        widget.block.value != _text.text) {
      _text.text = widget.block.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isText = widget.block.type == ExamContentBlockType.text;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isText ? Icons.text_fields : Icons.functions,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isText ? 'نص' : 'معادلة رياضية / علمية',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'تحريك لأعلى',
                  onPressed: widget.index == 0 ? null : widget.onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: 'تحريك لأسفل',
                  onPressed: widget.index == widget.total - 1
                      ? null
                      : widget.onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: widget.total == 1 ? null : widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (isText)
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'اكتب نص السؤال هنا...',
                  border: OutlineInputBorder(),
                ),
                onChanged: widget.onTextChanged,
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Math.tex(
                      widget.block.value,
                      mathStyle: MathStyle.display,
                      onErrorFallback: (_) =>
                          const Text('تعذر عرض المعادلة'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onEditEquation,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تحرير المعادلة'),
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

class _EquationDialog extends StatefulWidget {
  const _EquationDialog({required this.initial});

  final String initial;

  @override
  State<_EquationDialog> createState() => _EquationDialogState();
}

class _EquationDialogState extends State<_EquationDialog> {
  late final MathFieldEditingController _controller;

  static const _symbols = <String, String>{
    'π': r'\pi',
    '√': r'\sqrt{ }',
    '∞': r'\infty',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'θ': r'\theta',
    'λ': r'\lambda',
    'μ': r'\mu',
    'Ω': r'\Omega',
    '≤': r'\le',
    '≥': r'\ge',
    '≠': r'\ne',
    '±': r'\pm',
    '→': r'\rightarrow',
    '×': r'\times',
    '÷': r'\div',
  };

  @override
  void initState() {
    super.initState();
    _controller = MathFieldEditingController();
    _controller.text = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertSymbol(String tex) {
    _controller.text = '${_controller.text} $tex ';
  }

  @override
  Widget build(BuildContext context) {
    return MathKeyboardViewInsets(
      child: AlertDialog(
        title: const Text('محرر المعادلات والرموز'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MathField(
                  controller: _controller,
                  variables: const ['a', 'b', 'c', 'x', 'y', 'z'],
                  keyboardType: MathKeyboardType.expression,
                  decoration: const InputDecoration(
                    labelText: 'المعادلة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'رموز سريعة',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in _symbols.entries)
                      OutlinedButton(
                        onPressed: () => _insertSymbol(entry.value),
                        child: Text(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'أمثلة: كسر، جذر، أس، مؤشرات، دوال مثل sin و cos و ln، والرموز الفيزيائية والرياضية.',
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: 10),
                if (_controller.text.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Math.tex(
                      _controller.text,
                      mathStyle: MathStyle.display,
                      onErrorFallback: (_) =>
                          const Text('راجع صيغة المعادلة.'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = _controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            icon: const Icon(Icons.check),
            label: const Text('إدراج المعادلة'),
          ),
        ],
      ),
    );
  }
}

class _PaperTemplateDialog extends StatefulWidget {
  const _PaperTemplateDialog({required this.initial});

  final ExamPaperTemplate initial;

  @override
  State<_PaperTemplateDialog> createState() => _PaperTemplateDialogState();
}

class _PaperTemplateDialogState extends State<_PaperTemplateDialog> {
  late final Map<String, TextEditingController> _fields;
  late bool _showQuestionMarks;
  late bool _showPageNumber;

  static const _fieldDefinitions = <String, String>{
    'ministry': 'الجهة العليا',
    'educationOffice': 'مكتب التربية',
    'educationAdministration': 'إدارة التربية والتعليم',
    'schoolName': 'اسم المدرسة',
    'examTitle': 'عنوان الاختبار',
    'academicYear': 'العام الدراسي',
    'subjectLabel': 'عنوان خانة المادة',
    'gradeLabel': 'عنوان خانة الصف',
    'dateLabel': 'عنوان خانة التاريخ',
    'durationLabel': 'عنوان خانة الزمن',
    'instruction': 'تعليمات الاختبار',
    'footerRight': 'التذييل الأيمن',
    'footerLeft': 'التذييل الأيسر',
  };

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _fields = {
      'ministry': TextEditingController(text: t.ministry),
      'educationOffice': TextEditingController(text: t.educationOffice),
      'educationAdministration':
          TextEditingController(text: t.educationAdministration),
      'schoolName': TextEditingController(text: t.schoolName),
      'examTitle': TextEditingController(text: t.examTitle),
      'academicYear': TextEditingController(text: t.academicYear),
      'subjectLabel': TextEditingController(text: t.subjectLabel),
      'gradeLabel': TextEditingController(text: t.gradeLabel),
      'dateLabel': TextEditingController(text: t.dateLabel),
      'durationLabel': TextEditingController(text: t.durationLabel),
      'instruction': TextEditingController(text: t.instruction),
      'footerRight': TextEditingController(text: t.footerRight),
      'footerLeft': TextEditingController(text: t.footerLeft),
    };
    _showQuestionMarks = t.showQuestionMarks;
    _showPageNumber = t.showPageNumber;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تخصيص كليشة الاختبار'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final entry in _fieldDefinitions.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _fields[entry.key],
                    minLines: entry.key == 'instruction' ? 2 : 1,
                    maxLines: entry.key == 'instruction' ? 4 : 1,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار درجات الأسئلة'),
                value: _showQuestionMarks,
                onChanged: (value) =>
                    setState(() => _showQuestionMarks = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار رقم الصفحة'),
                value: _showPageNumber,
                onChanged: (value) =>
                    setState(() => _showPageNumber = value),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'هذا القالب مبني على بنية الورقة المرجعية: رأس ثلاثي الأعمدة، شريط التعليمات، مساحة الأسئلة، وتذييل الصفحة. الشعار والصور سيتم ربطها في خطوة تصميم القالب A4.',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(
              context,
              widget.initial.copyWith(
                ministry: _fields['ministry']!.text.trim(),
                educationOffice: _fields['educationOffice']!.text.trim(),
                educationAdministration:
                    _fields['educationAdministration']!.text.trim(),
                schoolName: _fields['schoolName']!.text.trim(),
                examTitle: _fields['examTitle']!.text.trim(),
                academicYear: _fields['academicYear']!.text.trim(),
                subjectLabel: _fields['subjectLabel']!.text.trim(),
                gradeLabel: _fields['gradeLabel']!.text.trim(),
                dateLabel: _fields['dateLabel']!.text.trim(),
                durationLabel: _fields['durationLabel']!.text.trim(),
                instruction: _fields['instruction']!.text.trim(),
                footerRight: _fields['footerRight']!.text.trim(),
                footerLeft: _fields['footerLeft']!.text.trim(),
                showQuestionMarks: _showQuestionMarks,
                showPageNumber: _showPageNumber,
              ),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الكليشة'),
        ),
      ],
    );
  }
}
