import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'exam_official_assets.dart';

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

    final pageFormat = PdfPageFormat(
      _OfficialPaperGeometry.a4Width,
      _OfficialPaperGeometry.a4Height,
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

/// Official A4 geometry derived from the supplied reference paper.
/// The source page is A4 portrait (210 × 297 mm = 595.28 × 841.89 pt).
/// Keep these values centralized so the official sheet is not altered
/// accidentally by responsive UI changes.
abstract final class _OfficialPaperGeometry {
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;

  // Printable frame measured from the supplied reference layout.
  static const double outerMargin = 15.3;
  static const double frameBorderWidth = 2.25;
  static const double innerPaddingHorizontal = 13.45;
  static const double innerPaddingTop = 13.45;
  static const double innerPaddingBottom = 10.0;

  static const double headerBorderWidth = 1.2;
  static const double headerHeight = 78.5;
}

/// Typography scale used by the official header. Do not replace these
/// values with adaptive Material typography; the exam sheet is a fixed
/// printable document, not a normal responsive screen.
abstract final class _OfficialPaperTypography {
  static const double headerRegular = 8.7;
  static const double headerTitle = 9.2;
  static const double body = 10.0;
  static const double footer = 8.5;
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
        padding: const EdgeInsets.all(_OfficialPaperGeometry.outerMargin),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: _OfficialPaperGeometry.frameBorderWidth),
          ),
          padding: const EdgeInsets.fromLTRB(
            _OfficialPaperGeometry.innerPaddingHorizontal,
            _OfficialPaperGeometry.innerPaddingTop,
            _OfficialPaperGeometry.innerPaddingHorizontal,
            _OfficialPaperGeometry.innerPaddingBottom,
          ),
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

    return SizedBox(
      height: _OfficialPaperGeometry.headerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black,
            width: _OfficialPaperGeometry.headerBorderWidth,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 228,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      height: 24,
                      child: Image.memory(
                        officialMinistryWordmarkImage,
                        width: 100,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 1),
                    _HeaderText(t.ministry, bold: true),
                    _HeaderText(t.educationOffice),
                    _HeaderText(t.educationAdministration),
                    _HeaderText(t.schoolName, bold: true),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 275,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      height: 37,
                      child: Image.memory(
                        officialYemenEmblemImage,
                        width: 96,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 1),
                    _HeaderText(
                      t.examTitle.isEmpty ? exam.title : t.examTitle,
                      bold: true,
                      fontSize: _OfficialPaperTypography.headerTitle,
                    ),
                    if (t.academicYear.trim().isNotEmpty)
                      _HeaderText(t.academicYear),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 185,
              child: _HeaderCell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(
    this.text, {
    this.bold = false,
    this.fontSize = _OfficialPaperTypography.headerRegular,
  });

  final String text;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text.isEmpty ? ' ' : text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          height: 1.05,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
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
    return Expanded(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 1,
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black,
                fontSize: _OfficialPaperTypography.headerRegular,
                height: 1.0,
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
