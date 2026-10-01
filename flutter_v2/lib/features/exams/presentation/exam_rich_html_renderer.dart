import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Lightweight renderer for the controlled HTML emitted by the MExam-style
/// question editor. It intentionally supports the editor's semantic subset
/// instead of depending on a browser/CSS engine in the A4 print path.
class ExamRichHtmlRenderer extends StatelessWidget {
  const ExamRichHtmlRenderer({required this.html, this.fontSize = 10, super.key});
  final String html;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fragment = html_parser.parseFragment(html);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (final node in fragment.nodes) ..._renderBlock(node)],
      ),
    );
  }

  List<Widget> _renderBlock(dom.Node node) {
    if (node is dom.Text) {
      final text = _decode(node.data);
      if (text.trim().isEmpty) return const [];
      return [Text(text, textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.35))];
    }
    if (node is! dom.Element) return const [];
    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'br') return const [SizedBox(height: 2)];
    if (tag == 'table') return [_renderTable(node)];
    if (tag == 'ul' || tag == 'ol') {
      return [Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < node.children.length; i++)
            _listItem(node.children[i], i + 1, tag == 'ol'),
        ],
      )];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _inlineRich(node),
      ),
    ];
  }

  Widget _listItem(dom.Element element, int index, bool ordered) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(width: 18, child: Text(ordered ? '$index.' : '•', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: fontSize))),
        Expanded(child: _inlineRich(element)),
      ],
    );
  }

  Widget _inlineRich(dom.Node node) {
    final spans = <InlineSpan>[];
    _collectInline(node, spans, const TextStyle(color: Colors.black));
    return RichText(
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.35),
        children: spans,
      ),
    );
  }

  void _collectInline(dom.Node node, List<InlineSpan> out, TextStyle style) {
    if (node is dom.Text) {
      final text = _decode(node.data);
      if (text.isNotEmpty) out.add(TextSpan(text: text, style: style));
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    var nextStyle = style;
    if (tag == 'strong' || tag == 'b') {
      nextStyle = nextStyle.copyWith(fontWeight: FontWeight.bold);
    } else if (tag == 'em' || tag == 'i') {
      nextStyle = nextStyle.copyWith(fontStyle: FontStyle.italic);
    } else if (tag == 'u') {
      nextStyle = nextStyle.copyWith(decoration: TextDecoration.underline);
    }

    if (tag == 'sup' || tag == 'sub') {
      out.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
          offset: Offset(0, tag == 'sup' ? -2 : 2),
          child: Text(node.text, style: nextStyle.copyWith(fontSize: fontSize * .68)),
        ),
      ));
      return;
    }

    final classes = (node.attributes['class'] ?? '').split(RegExp(r'\s+'));
    if (classes.contains('frac')) {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _fraction(node)));
      return;
    }
    if (classes.contains('root')) {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _root(node)));
      return;
    }
    if (classes.contains('limit')) {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _limit(node)));
      return;
    }
    if (classes.contains('matrix') || tag == 'table') {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _renderTable(node)));
      return;
    }
    if (classes.contains('vector')) {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _vector(node)));
      return;
    }
    if (classes.contains('isotope')) {
      out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _isotope(node)));
      return;
    }
    if (classes.contains('chem') || classes.contains('physics-unit')) {
      final scientificStyle = nextStyle.copyWith(fontFamily: 'Arial');
      for (final child in node.nodes) {
        _collectInline(child, out, scientificStyle);
      }
      return;
    }
    if (classes.contains('science-template')) {
      out.add(TextSpan(text: node.text, style: nextStyle.copyWith(fontWeight: FontWeight.w600)));
      return;
    }

    for (final child in node.nodes) {
      _collectInline(child, out, nextStyle);
    }
  }

  Widget _fraction(dom.Element node) {
    final num = node.querySelector('.num')?.text ?? 'a';
    final den = node.querySelector('.den')?.text ?? 'b';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(num, style: TextStyle(color: Colors.black, fontSize: fontSize * .9)),
          Container(width: 28, height: 1, color: Colors.black),
          Text(den, style: TextStyle(color: Colors.black, fontSize: fontSize * .9)),
        ],
      ),
    );
  }

  Widget _root(dom.Element node) {
    final body = node.querySelector('.body')?.text ?? 'x';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('√', style: TextStyle(color: Colors.black, fontSize: fontSize * 1.15)),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: .8))),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(body, style: TextStyle(color: Colors.black, fontSize: fontSize)),
        ),
      ],
    );
  }

  Widget _limit(dom.Element node) {
    final parts = node.children.where((e) => e.text.trim().isNotEmpty).toList();
    if (parts.isEmpty) return Text('lim', style: TextStyle(color: Colors.black, fontSize: fontSize));
    if (node.text.contains('Σ')) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(parts.last.text, style: TextStyle(color: Colors.black, fontSize: fontSize * .65)),
          Text('Σ', style: TextStyle(color: Colors.black, fontSize: fontSize * 1.25)),
          Text(parts.first.text, style: TextStyle(color: Colors.black, fontSize: fontSize * .65)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('lim', style: TextStyle(color: Colors.black, fontSize: fontSize)),
        Text(parts.length > 1 ? parts[1].text : parts.first.text, style: TextStyle(color: Colors.black, fontSize: fontSize * .65)),
      ],
    );
  }

  Widget _vector(dom.Element node) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(node.text, style: TextStyle(color: Colors.black, fontSize: fontSize)),
        ),
        const Positioned(top: -2, child: Text('→', style: TextStyle(color: Colors.black, fontSize: 8))),
      ],
    );
  }

  Widget _isotope(dom.Element node) {
    final mass = node.querySelector('.mass')?.text ?? '14';
    final element = node.querySelector('.element')?.text ?? 'C';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mass, style: TextStyle(color: Colors.black, fontSize: fontSize * .62)),
        Text(element, style: TextStyle(color: Colors.black, fontSize: fontSize)),
      ],
    );
  }

  Widget _renderTable(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: Colors.black, width: .6),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row.children.where((e) => e.localName == 'td' || e.localName == 'th'))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text(cell.text, textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: fontSize * .9)),
                ),
            ],
          ),
      ],
    );
  }

  String _decode(String text) {
    return text.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"');
  }
}
