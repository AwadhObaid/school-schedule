import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'exam_official_assets.dart';
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
  final GlobalKey _captureKey = GlobalKey();
  int _capturePageIndex = 0;
  final TransformationController _transformController =
      TransformationController();

  double _zoom = 1.0;
  int _currentPage = 0;
  bool _loading = true;
  Uint8List? _pdfBytes;
  List<Uint8List> _pageImages = const <Uint8List>[];

  @override
  void initState() {
    super.initState();
    _pages = _paginate(widget.exam.questions);
    _loadPreview();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final bytes = await _buildPdf(context, PdfPageFormat.a4);
      final images = <Uint8List>[];

      await for (final page in Printing.raster(bytes, dpi: 150)) {
        images.add(await page.toPng());
      }

      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _pageImages = images;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تجهيز معاينة الورقة: $error')),
      );
    }
  }

  void _setZoom(double value) {
    final next = value.clamp(0.5, 3.0).toDouble();
    setState(() => _zoom = next);
    _transformController.value = Matrix4.identity()..scale(next);
  }

  void _zoomIn() => _setZoom(_zoom + 0.25);

  void _zoomOut() => _setZoom(_zoom - 0.25);

  void _resetZoom() => _setZoom(1.0);

  Future<void> _print() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(widget.exam),
    );
  }

  Future<void> _share() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(widget.exam),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ورقة الاختبار A4 • معاينة PDF'),
        actions: [
          IconButton(
            tooltip: 'تصغير',
            onPressed: _loading || _zoom <= 0.5 ? null : _zoomOut,
            icon: const Icon(Icons.remove),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '${(_zoom * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تكبير',
            onPressed: _loading || _zoom >= 3.0 ? null : _zoomIn,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'ملاءمة الصفحة',
            onPressed: _loading ? null : _resetZoom,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
          IconButton(
            tooltip: 'مشاركة PDF',
            onPressed: _pdfBytes == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'طباعة',
            onPressed: _pdfBytes == null ? null : _print,
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('جاري تجهيز معاينة ورقة A4...'),
                ],
              ),
            )
          else if (_pageImages.isEmpty)
            const Center(child: Text('لا توجد صفحات للمعاينة.'))
          else
            Container(
              color: const Color(0xFFE5E7EB),
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: _pageImages.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) => InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.5,
                      maxScale: 3.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      boundaryMargin: const EdgeInsets.all(120),
                      onInteractionUpdate: (_) {
                        final scale = _transformController.value.getMaxScaleOnAxis();
                        if ((scale - _zoom).abs() > 0.01 && mounted) {
                          setState(() => _zoom = scale.clamp(0.5, 3.0).toDouble());
                        }
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Image.memory(
                            _pageImages[index],
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_pageImages.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            child: Text(
                              'الصفحة ' + (_currentPage + 1).toString() + ' من ' + _pageImages.length.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Keep exactly one live A4 render target in the normal Flutter
          // tree. Capturing many boundaries at once made table-heavy pages
          // vulnerable to clipping/paint-order issues.
          IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: _OfficialPaperGeometry.a4Width,
                maxWidth: _OfficialPaperGeometry.a4Width,
                minHeight: _OfficialPaperGeometry.a4Height,
                maxHeight: _OfficialPaperGeometry.a4Height,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: SizedBox(
                    width: _OfficialPaperGeometry.a4Width,
                    height: _OfficialPaperGeometry.a4Height,
                    child: _PaperPage(
                      exam: widget.exam,
                      pageNumber: _capturePageIndex + 1,
                      totalPages: _pages.length,
                      questions: _pages[_capturePageIndex],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

    await loadOfficialExamFont();

    for (var index = 0; index < _pages.length; index++) {
      if (!mounted) {
        throw StateError('تم إغلاق شاشة المعاينة أثناء تجهيز الصفحة.');
      }

      // Switch the single live render target to this page, then wait for
      // layout + paint to settle before calling RenderRepaintBoundary.toImage.
      if (_capturePageIndex != index) {
        setState(() => _capturePageIndex = index);
      }
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final renderObject =
          _captureKey.currentContext?.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('تعذر تجهيز صفحة ' + (index + 1).toString() + ' للمعاينة.');
      }

      var paintAttempts = 0;
      while (renderObject.debugNeedsPaint && paintAttempts < 3) {
        paintAttempts++;
        await WidgetsBinding.instance.endOfFrame;
      }
      if (renderObject.debugNeedsPaint) {
        throw StateError('لم تكتمل عملية رسم صفحة ' + (index + 1).toString() + '.');
      }

      final image = await renderObject.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        image.dispose();
        throw StateError('تعذر تحويل صفحة ' + (index + 1).toString() + ' إلى PNG.');
      }

      final pngBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      image.dispose();

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

      // A manual page break always wins over automatic pagination.
      if (question.pageBreakBefore && current.isNotEmpty) {
        pages.add(List.unmodifiable(current));
        current = <ExamQuestion>[];
        used = 0;
      }

      // Questions are atomic paper blocks: a question, including its tables,
      // options and answer area, is never split between two A4 pages.
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

    final html = question.htmlContent;
    final tableRows = RegExp(r'<tr\\b', caseSensitive: false)
        .allMatches(html)
        .length;
    final tableCells = RegExp(r'<(?:td|th)\\b', caseSensitive: false)
        .allMatches(html)
        .length;
    if (tableRows > 0) {
      // Tables in the reference exam are substantial blocks. Reserve space
      // for every row and a little extra for headings/borders.
      units += 1.4 + (tableRows * 1.55);
      if (tableCells > tableRows * 2) {
        units += ((tableCells - tableRows * 2) / 4) * 0.35;
      }
    }

    final htmlBlocks = RegExp(r'<(?:div|p|br)\\b', caseSensitive: false)
        .allMatches(html)
        .length;
    if (htmlBlocks > 1) {
      units += ((htmlBlocks - 1) * 0.22).clamp(0, 2.5);
    }

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
  static const double instructionHeight = 25.0;
  static const double contentLeft = outerMargin + innerPaddingHorizontal;
  static const double contentTop = outerMargin + innerPaddingTop;
  static const double contentWidth =
      a4Width - (2 * (outerMargin + innerPaddingHorizontal));
  static const double contentRight =
      a4Width - contentLeft - contentWidth;
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
      child: Container(
        color: Colors.white,
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
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/yemen_republic_wordmark.svg',
                          width: 108,
                          height: 22,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
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
                        child: SvgPicture.asset(
                          'assets/images/yemen_emblem_transparent.svg',
                          width: 112,
                          height: 42,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
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
          fontFamily: officialExamFontFamily,
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
              style: TextStyle(
                color: Colors.black,
                fontFamily: officialExamFontFamily,
                fontSize: _OfficialPaperTypography.headerRegular,
                height: 1.0,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontFamily: officialExamFontFamily,
                    fontWeight: FontWeight.bold,
                  ),
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
              style: TextStyle(
                color: Colors.black,
                fontFamily: officialExamFontFamily,
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
                template.teacherName.trim().isNotEmpty
                    ? template.teacherName
                    : template.footerRight,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: officialExamFontFamily,
                  fontSize: 8.5,
                ),
              ),
            ),
            if (template.showPageNumber)
              Text(
                'الصفحة رقم $pageNumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: officialExamFontFamily,
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
