import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'exam_official_assets.dart';
import 'exam_official_font.dart';
import 'exam_rich_html_renderer.dart';

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

      // The body remains rasterized for reliable Arabic/HTML/equation layout,
      // while the official header and instruction bar are rebuilt natively in
      // the PDF so their text is vector-sharp.
      final pngBytes = await _rawRgbaToPng(wrapped);
      final emblemPng = await _whiteToTransparentPng(
        officialYemenEmblemImage,
      );
      final wordmarkPng = await _whiteToTransparentPng(
        officialMinistryWordmarkImage,
      );
      final officialFont = await _loadPdfOfficialFont();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(
                  pw.MemoryImage(pngBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
              pw.Positioned(
                left: _OfficialPaperGeometry.contentLeft,
                top: _OfficialPaperGeometry.contentTop,
                width: _OfficialPaperGeometry.contentWidth,
                height: _OfficialPaperGeometry.headerHeight,
                child: _PdfOfficialHeader(
                  exam: widget.exam,
                  font: officialFont,
                  emblem: pw.MemoryImage(emblemPng),
                  wordmark: pw.MemoryImage(wordmarkPng),
                ),
              ),
              pw.Positioned(
                left: _OfficialPaperGeometry.contentLeft,
                top: _OfficialPaperGeometry.instructionTop,
                width: _OfficialPaperGeometry.contentWidth,
                height: _OfficialPaperGeometry.instructionHeight,
                child: _PdfInstructionBar(
                  text: widget.exam.template.instruction,
                  font: officialFont,
                ),
              ),
            ],
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

Future<Uint8List> _whiteToTransparentPng(Uint8List source) async {
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    image.dispose();
    codec.dispose();
    throw StateError('تعذر معالجة الصورة الرسمية.');
  }
  final bytes = Uint8List.fromList(data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  ));
  final width = image.width;
  final height = image.height;
  final visited = Uint8List(width * height);
  final queue = <int>[];

  void seed(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final index = y * width + x;
    if (visited[index] != 0) return;
    final p = index * 4;
    final nearWhite =
        bytes[p] > 245 && bytes[p + 1] > 245 && bytes[p + 2] > 245;
    if (!nearWhite || bytes[p + 3] == 0) return;
    visited[index] = 1;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    seed(x, 0);
    seed(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    seed(0, y);
    seed(width - 1, y);
  }

  var cursor = 0;
  while (cursor < queue.length) {
    final index = queue[cursor++];
    final p = index * 4;
    bytes[p + 3] = 0;
    final x = index % width;
    final y = index ~/ width;
    seed(x - 1, y);
    seed(x + 1, y);
    seed(x, y - 1);
    seed(x, y + 1);
  }
  final raw = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = ui.ImageDescriptor.raw(
    raw,
    width: image.width,
    height: image.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final rawCodec = await descriptor.instantiateCodec();
  final rawFrame = await rawCodec.getNextFrame();
  final png = await rawFrame.image.toByteData(format: ui.ImageByteFormat.png);
  rawFrame.image.dispose();
  rawCodec.dispose();
  descriptor.dispose();
  raw.dispose();
  image.dispose();
  codec.dispose();
  if (png == null) throw StateError('تعذر إنشاء صورة PNG شفافة.');
  return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

Future<pw.Font> _loadPdfOfficialFont() async {
  final ttf = Uint8List.fromList(
    GZipDecoder().decodeBytes(base64Decode(officialAmiriGzipBase64)),
  );
  return pw.Font.ttf(ByteData.sublistView(ttf));
}

class _PdfOfficialHeader extends pw.StatelessWidget {
  _PdfOfficialHeader({
    required this.exam,
    required this.font,
    required this.emblem,
    required this.wordmark,
  });

  final Exam exam;
  final pw.Font font;
  final pw.MemoryImage emblem;
  final pw.MemoryImage wordmark;

  @override
  pw.Widget build(pw.Context context) {
    final t = exam.template;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: _OfficialPaperGeometry.headerBorderWidth),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 185,
            child: _pdfCell(pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _pdfInfoLine(t.subjectLabel, exam.subject, font),
                _pdfInfoLine(t.gradeLabel, exam.className, font),
                _pdfInfoLine(t.dateLabel, '___ / ___ / ______م', font),
                _pdfInfoLine(t.durationLabel, _durationLabelForPdf(exam.durationMinutes), font),
              ],
            )),
          ),
          pw.Expanded(
            flex: 275,
            child: _pdfCell(pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.SizedBox(
                  height: 37,
                  child: pw.Center(child: pw.Image(emblem, width: 96, height: 37, fit: pw.BoxFit.contain)),
                ),
                _pdfHeaderText(t.examTitle.isEmpty ? exam.title : t.examTitle, font, bold: true, size: _OfficialPaperTypography.headerTitle),
                if (t.academicYear.trim().isNotEmpty) _pdfHeaderText(t.academicYear, font),
              ],
            )),
          ),
          pw.Expanded(
            flex: 228,
            child: _pdfCell(pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.SizedBox(height: 24, child: pw.Image(wordmark, width: 100, fit: pw.BoxFit.contain)),
                _pdfHeaderText(t.ministry, font, bold: true),
                _pdfHeaderText(t.educationOffice, font),
                _pdfHeaderText(t.educationAdministration, font),
                _pdfHeaderText(t.schoolName, font, bold: true),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

pw.Widget _pdfCell(pw.Widget child) => pw.Container(
  alignment: pw.Alignment.center,
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  decoration: const pw.BoxDecoration(
    border: pw.Border(left: pw.BorderSide(color: PdfColors.black, width: 1)),
  ),
  child: child,
);

pw.Widget _pdfHeaderText(String value, pw.Font font, {bool bold = false, double size = _OfficialPaperTypography.headerRegular}) =>
    pw.SizedBox(
      width: double.infinity,
      child: pw.Text(
        value.isEmpty ? ' ' : value,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
        style: pw.TextStyle(font: font, fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );

pw.Widget _pdfInfoLine(String label, String value, pw.Font font) => pw.Expanded(
  child: pw.Center(
    child: pw.Text(
      label + ': ' + (value.isEmpty ? '—' : value),
      textAlign: pw.TextAlign.center,
      maxLines: 1,
      style: pw.TextStyle(font: font, fontSize: _OfficialPaperTypography.headerRegular),
    ),
  ),
);

class _PdfInstructionBar extends pw.StatelessWidget {
  _PdfInstructionBar({required this.text, required this.font});
  final String text;
  final pw.Font font;
  @override
  pw.Widget build(pw.Context context) => pw.Container(
    height: _OfficialPaperGeometry.instructionHeight,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
    child: pw.Row(children: [
      pw.Container(width: 28, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1))), child: pw.Text('س', style: pw.TextStyle(font: font, fontSize: 10))),
      pw.Expanded(child: pw.Center(child: pw.Text(text.isEmpty ? 'أجب عن جميع الأسئلة التالية:' : text, textAlign: pw.TextAlign.center, maxLines: 1, style: pw.TextStyle(font: font, fontSize: 9.5, fontWeight: pw.FontWeight.bold)))),
      pw.Container(width: 28, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: PdfColors.black, width: 1))), child: pw.Text('د', style: pw.TextStyle(font: font, fontSize: 10))),
    ]),
  );
}

String _durationLabelForPdf(int minutes) {
  if (minutes % 60 == 0) return minutes == 60 ? 'ساعة' : '${minutes ~/ 60} ساعات';
  if (minutes > 60) return '${minutes ~/ 60} ساعة و ${minutes % 60} دقيقة';
  return '$minutes دقيقة';
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
  static const double instructionHeight = 25.0;
  static const double contentLeft = outerMargin + innerPaddingHorizontal;
  static const double contentTop = outerMargin + innerPaddingTop;
  static const double contentWidth =
      a4Width - (2 * (outerMargin + innerPaddingHorizontal));
  static const double instructionTop = contentTop + headerHeight + 5.0;
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
                      width: double.infinity,
                      height: 37,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(20, 0),
                          child: Image.memory(
                            officialYemenEmblemImage,
                            width: 96,
                            height: 37,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
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
          if (question.htmlContent.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ExamRichHtmlRenderer(
                html: question.htmlContent,
                fontSize: _OfficialPaperTypography.body,
              ),
            )
          else
            for (final block in question.effectiveContent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: block.type == ExamContentBlockType.text
                    ? Text(
                        block.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: _OfficialPaperTypography.body,
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
                            style: TextStyle(color: Colors.black, fontSize: 9),
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
