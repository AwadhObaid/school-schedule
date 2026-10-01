import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/models/exam.dart';
import '../../../core/models/exam_content_block.dart';
import '../../../core/models/exam_paper_template.dart';

class ExamPaperPreviewScreen extends StatelessWidget {
  const ExamPaperPreviewScreen({
    required this.exam,
    super.key,
  });

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final pages = _paginate(exam.questions);

    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة ورقة الاختبار A4 • ${pages.length} صفحة'),
        actions: [
          IconButton(
            tooltip: 'معلومات المعاينة',
            onPressed: () => _showInfo(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                (constraints.maxWidth - 32).clamp(280.0, 900.0);
            final pageHeight = availableWidth * 297 / 210;

            return PageView.builder(
              controller: PageController(),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: availableWidth,
                      height: pageHeight,
                      child: Material(
                        color: Colors.white,
                        elevation: 2,
                        child: _PaperPage(
                          exam: exam,
                          pageNumber: index + 1,
                          totalPages: pages.length,
                          questions: pages[index],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<List<ExamQuestion>> _paginate(List<ExamQuestion> questions) {
    if (questions.isEmpty) return const <List<ExamQuestion>>[<ExamQuestion>[]];

    // Temporary visual pagination for the A4 preview.
    // Phase 15D will replace this with measured PDF pagination.
    const capacity = 5;
    final pages = <List<ExamQuestion>>[];

    for (var i = 0; i < questions.length; i += capacity) {
      final end = (i + capacity < questions.length)
          ? i + capacity
          : questions.length;
      pages.add(List.unmodifiable(questions.sublist(i, end)));
    }

    return pages;
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('معاينة A4'),
        content: Text(
          'هذه المرحلة تعرض الكليشة ومحتوى الأسئلة داخل مساحة ورقة A4. '
          'التصدير إلى PDF والطباعة المباشرة ستكون في المرحلة التالية.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({
    required this.exam,
    required this.pageNumber,
    required this.totalPages,
    required this.questions,
  });

  final Exam exam;
  final int pageNumber;
  final int totalPages;
  final List<ExamQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final template = exam.template;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        child: Column(
          children: [
            _PaperHeader(exam: exam),
            const SizedBox(height: 5),
            _InstructionBar(text: template.instruction),
            const SizedBox(height: 10),
            Expanded(
              child: questions.isEmpty
                  ? _EmptyQuestionArea()
                  : _QuestionsArea(
                      questions: questions,
                      showMarks: template.showQuestionMarks,
                    ),
            ),
            const SizedBox(height: 8),
            _PaperFooter(
              template: template,
              pageNumber: pageNumber,
              totalPages: totalPages,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperHeader extends StatelessWidget {
  const _PaperHeader({required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final t = exam.template;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeaderText(t.ministry, bold: true),
                    _HeaderText(t.educationOffice),
                    _HeaderText(t.educationAdministration),
                    _HeaderText(t.schoolName, bold: true),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _HeaderText(
                      t.examTitle.isEmpty ? exam.title : t.examTitle,
                      bold: true,
                    ),
                    if (t.academicYear.trim().isNotEmpty)
                      _HeaderText(t.academicYear),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoLine(t.subjectLabel, exam.subject),
                    _InfoLine(t.gradeLabel, exam.className),
                    _InfoLine(t.dateLabel, '___ / ___ / ______م'),
                    _InfoLine(
                      t.durationLabel,
                      _durationLabel(exam.durationMinutes),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _durationLabel(int minutes) {
    if (minutes % 60 == 0) {
      return minutes == 60 ? 'ساعة' : '${minutes ~/ 60} ساعات';
    }
    if (minutes > 60) {
      return '${minutes ~/ 60} ساعة و ${minutes % 60} دقيقة';
    }
    return '$minutes دقيقة';
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: child,
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.isEmpty ? ' ' : text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.black,
        fontSize: 9.5,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black,
            fontSize: 9.5,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value.isEmpty ? '—' : value),
          ],
        ),
      ),
    );
  }
}

class _InstructionBar extends StatelessWidget {
  const _InstructionBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            child: const Text(
              'س',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? 'أجب عن جميع الأسئلة التالية:' : text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            child: const Text(
              'د',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionsArea extends StatelessWidget {
  const _QuestionsArea({
    required this.questions,
    required this.showMarks,
  });

  final List<ExamQuestion> questions;
  final bool showMarks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black12,
          width: 0.8,
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < questions.length; i++)
              _QuestionOnPaper(
                number: i + 1,
                question: questions[i],
                showMarks: showMarks,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuestionArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black12,
          width: 0.8,
          style: BorderStyle.solid,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        '✏️  مساحة الأسئلة فارغة — أضف سؤالًا واختر الصفحة 1 لبدء الكتابة هنا',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF9AA0A6),
          fontSize: 10,
        ),
      ),
    );
  }
}

class _QuestionOnPaper extends StatelessWidget {
  const _QuestionOnPaper({
    required this.number,
    required this.question,
    required this.showMarks,
  });

  final int number;
  final ExamQuestion question;
  final bool showMarks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMarks)
                Text(
                  '(${_marks(question.marks)})',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                  ),
                ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'س${number}/',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          for (final block in question.effectiveContent)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: block.type == ExamContentBlockType.text
                  ? Text(
                      block.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: Math.tex(
                        block.value,
                        mathStyle: MathStyle.display,
                        onErrorFallback: (_) => const Text(
                          'معادلة غير صالحة',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
            ),
          if (question.type == ExamQuestionType.multipleChoice &&
              question.options.isNotEmpty)
            _ChoiceOptions(
              options: question.options,
            ),
          if (question.type == ExamQuestionType.trueFalse)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                '☐ صح     ☐ خطأ',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                ),
              ),
            ),
          if (question.type == ExamQuestionType.shortAnswer ||
              question.type == ExamQuestionType.essay)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Divider(
                color: Colors.black38,
                height: 10,
              ),
            ),
        ],
      ),
    );
  }

  static String _marks(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.options});

  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 18,
        runSpacing: 3,
        children: [
          for (var i = 0; i < options.length; i++)
            Text(
              '${_letter(i)}) ${options[i]}',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9.5,
              ),
            ),
        ],
      ),
    );
  }

  static String _letter(int index) {
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    return index < letters.length ? letters[index] : (index + 1).toString();
  }
}

class _PaperFooter extends StatelessWidget {
  const _PaperFooter({
    required this.template,
    required this.pageNumber,
    required this.totalPages,
  });

  final ExamPaperTemplate template;
  final int pageNumber;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.black,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                template.footerRight,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8.5,
                ),
              ),
            ),
            if (template.showPageNumber)
              Text(
                'الصفحة رقم $pageNumber',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8.5,
                ),
              ),
            Expanded(
              child: Text(
                template.footerLeft,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
