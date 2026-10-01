import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_widget_wrapper/pdf_widget_wrapper.dart';
import 'package:printing/printing.dart';

import '../../../core/models/exam.dart';
import '../../../core/models/exam_content_block.dart';
import '../../../core/models/exam_paper_template.dart';

class ExamPaperPreviewScreen extends StatefulWidget {
  const ExamPaperPreviewScreen({
    required this.exam,
    super.key,
  });

  final Exam exam;

  @override
  State<ExamPaperPreviewScreen> createState() => _ExamPaperPreviewScreenState();
}

class _ExamPaperPreviewScreenState extends State<ExamPaperPreviewScreen> {
  late final List<List<ExamQuestion>> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _paginate(widget.exam.questions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ورقة الاختبار A4 • معاينة PDF'),
      ),
      body: PdfPreview(
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        maxPageWidth: 850,
        pdfFileName: _fileName(widget.exam),
        build: (format) => _buildPdf(context, format),
      ),
    );
  }

  Future<Uint8List> _buildPdf(
    BuildContext context,
    PdfPageFormat format,
  ) async {
    final pdf = pw.Document(
      version: PdfVersion.pdf_1_5,
      compress: true,
    );

    final pageFormat = format.copyWith(
      marginLeft: 0,
      marginRight: 0,
      marginTop: 0,
      marginBottom: 0,
    );

    for (var index = 0; index < _pages.length; index++) {
      final pageWidget = _PaperPage(
        exam: widget.exam,
        pageNumber: index + 1,
        totalPages: _pages.length,
        questions: _pages[index],
      );

      final wrapped = await WidgetWrapper.fromWidget(
        context: context,
        widget: pageWidget,
        constraints: BoxConstraints.tight(
          Size(pageFormat.width, pageFormat.height),
        ),
        pixelRatio: 2.0,
        dpi: 144,
      );

      // WidgetWrapper exposes raw RGBA pixels. Convert them to PNG before
      // handing them to the PDF engine to avoid raw-image decoding issues.
      final pngBytes = await _rawRgbaToPng(wrapped);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.MemoryImage(pngBytes),
            width: pageFormat.width,
            height: pageFormat.height,
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }

    return pdf.save();
  }

  static Future<Uint8List> _rawRgbaToPng(WidgetWrapper wrapped) async {
    final width = wrapped.width;
    final height = wrapped.height;

    if (width == null || height == null || width <= 0 || height <= 0) {
      throw StateError('تعذر تحديد أبعاد صفحة الاختبار.');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(wrapped.bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    if (byteData == null) {
      throw StateError('تعذر تحويل صفحة الاختبار إلى صورة PNG.');
    }

    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }

  static List<List<ExamQuestion>> _paginate(
    List<ExamQuestion> questions,
  ) {
    if (questions.isEmpty) {
      return const <List<ExamQuestion>>[<ExamQuestion>[]];
    }

    // The page is a fixed A4 canvas. We use a vertical footprint estimate
    // instead of the old fixed "5 questions per page" rule.
    const pageCapacity = 24.0;
    final pages = <List<ExamQuestion>>[];
    var current = <ExamQuestion>[];
    var used = 0.0;

    for (final question in questions) {
      final footprint = _questionFootprint(question);
      if (current.isNotEmpty && used + footprint > pageCapacity) {
        pages.add(List.unmodifiable(current));
        current = <ExamQuestion>[];
        used = 0;
      }

      current.add(question);
      used += footprint;
    }

    if (current.isNotEmpty) {
      pages.add(List.unmodifiable(current));
    }

    return pages;
  }

  static double _questionFootprint(ExamQuestion question) {
    final textLength = question.prompt.trim().length;
    final textLines = (textLength / 62).ceil().clamp(1, 8);
    var units = 2.7 + textLines * 0.9;

    final equations = question.effectiveContent
        .where((block) => block.type == ExamContentBlockType.equation)
        .length;
    units += equations * 3.0;

    if (question.type == ExamQuestionType.multipleChoice) {
      final optionsLength =
          question.options.fold<int>(0, (sum, option) => sum + option.length);
      units += 1.5 + (optionsLength / 95).ceil() * 0.8;
    } else if (question.type == ExamQuestionType.trueFalse) {
      units += 1.0;
    } else if (question.type == ExamQuestionType.shortAnswer ||
        question.type == ExamQuestionType.essay) {
      units += 1.5;
    }

    return units;
  }

  static String _fileName(Exam exam) {
    final clean = exam.title.trim().replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
    return clean.isEmpty ? 'exam.pdf' : '$clean.pdf';
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
                  'س$number/',
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
