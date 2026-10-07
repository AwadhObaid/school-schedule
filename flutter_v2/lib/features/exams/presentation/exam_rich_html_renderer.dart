import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Renders the controlled HTML produced by the MExam-style editor.
/// Scientific structures are rendered as independent Flutter widgets so
/// they keep their geometry when the page is rasterized into the A4 PDF.
class ExamRichHtmlRenderer extends StatelessWidget {
  const ExamRichHtmlRenderer({
    required this.html,
    this.fontSize = 10,
    super.key,
  });

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
        children: [
          for (final node in fragment.nodes) _renderNode(node),
        ],
      ),
    );
  }

  Widget _renderNode(dom.Node node) {
    if (node is dom.Text) {
      final text = _decode(node.data);
      if (text.trim().isEmpty) return const SizedBox.shrink();
      return _text(text);
    }

    if (node is! dom.Element) return const SizedBox.shrink();

    final tag = node.localName?.toLowerCase() ?? '';
    final classes = _classes(node);

    if (tag == 'br') return const SizedBox(height: 5);

    if (classes.contains('frac')) return _fraction(node);
    if (classes.contains('root')) return _root(node);
    if (classes.contains('limit')) return _limit(node);
    if (classes.contains('matrix')) return _matrix(node);
    if (classes.contains('vector')) return _vector(node);
    if (classes.contains('isotope')) return _isotope(node);
    if (classes.contains('chem')) return _scientificText(node);
    if (classes.contains('physics-unit')) return _scientificText(node);
    if (classes.contains('science-template')) {
      return _centered(_scientificText(node));
    }
    if (tag == 'table') return _table(node);

    if (tag == 'ul' || tag == 'ol') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < node.children.length; i++)
              _listItem(node.children[i], i + 1, tag == 'ol'),
          ],
        ),
      );
    }

    if (tag == 'div' || tag == 'p') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: _inlineFlow(node),
      );
    }

    return _inlineFlow(node);
  }

  Widget _inlineFlow(dom.Element element) {
    final runs = <Widget>[];

    for (final child in element.nodes) {
      if (child is dom.Text) {
        final text = _decode(child.data).trim();
        if (text.isNotEmpty) {
          runs.add(_text(text));
        }
        continue;
      }

      if (child is! dom.Element) continue;

      final classes = _classes(child);
      final tag = child.localName?.toLowerCase() ?? '';

      if (classes.contains('frac')) {
        runs.add(_fraction(child));
      } else if (classes.contains('root')) {
        runs.add(_root(child));
      } else if (classes.contains('limit')) {
        runs.add(_limit(child));
      } else if (classes.contains('matrix')) {
        runs.add(_matrix(child));
      } else if (classes.contains('vector')) {
        runs.add(_vector(child));
      } else if (classes.contains('isotope')) {
        runs.add(_isotope(child));
      } else if (classes.contains('chem') ||
          classes.contains('physics-unit')) {
        runs.add(_scientificText(child));
      } else if (classes.contains('science-template')) {
        runs.add(_scientificText(child, bold: true));
      } else if (tag == 'br') {
        runs.add(const SizedBox(height: 5));
      } else if (tag == 'sup' || tag == 'sub') {
        runs.add(_script(child));
      } else if (tag == 'table') {
        runs.add(_table(child));
      } else {
        final nested = child.text.trim();
        if (nested.isNotEmpty) {
          runs.add(_styledInline(child));
        }
      }
    }

    if (runs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: runs.map((run) {
          return Align(
            alignment: Alignment.centerRight,
            child: run,
          );
        }).toList(),
      ),
    );
  }

  Widget _styledInline(dom.Element element) {
    final text = element.text;
    final tag = element.localName?.toLowerCase() ?? '';
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        height: 1.35,
        fontWeight:
            tag == 'strong' || tag == 'b' ? FontWeight.bold : FontWeight.normal,
        fontStyle: tag == 'em' || tag == 'i'
            ? FontStyle.italic
            : FontStyle.normal,
        decoration:
            tag == 'u' ? TextDecoration.underline : TextDecoration.none,
      ),
    );
  }

  Widget _script(dom.Element element) {
    final isSup = element.localName?.toLowerCase() == 'sup';
    return Transform.translate(
      offset: Offset(0, isSup ? -3 : 3),
      child: Text(
        element.text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize * .68,
          height: .8,
        ),
      ),
    );
  }

  Widget _fraction(dom.Element node) {
    final numerator = node.querySelector('.num')?.text.trim() ?? 'a';
    final denominator = node.querySelector('.den')?.text.trim() ?? 'b';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numerator,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: fontSize * .92),
          ),
          Container(
            width: 34,
            height: 1,
            color: Colors.black,
          ),
          Text(
            denominator,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: fontSize * .92),
          ),
        ],
      ),
    );
  }

  Widget _root(dom.Element node) {
    final body = node.querySelector('.body')?.text.trim() ?? 'x';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.ltr,
        children: [
          Text(
            '√',
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize * 1.25,
              height: 1,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: .8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limit(dom.Element node) {
    final children = node.children
        .where((item) => item.text.trim().isNotEmpty)
        .toList();

    if (node.text.contains('Σ')) {
      final lower = children.isNotEmpty ? children.first.text : 'i=1';
      final upper = children.length > 1 ? children.last.text : 'n';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              upper,
              style: TextStyle(color: Colors.black, fontSize: fontSize * .62),
            ),
            Text(
              'Σ',
              style: TextStyle(color: Colors.black, fontSize: fontSize * 1.35),
            ),
            Text(
              lower,
              style: TextStyle(color: Colors.black, fontSize: fontSize * .62),
            ),
          ],
        ),
      );
    }

    final target = children.isNotEmpty ? children.last.text : 'x→a';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'lim',
            style: TextStyle(color: Colors.black, fontSize: fontSize),
          ),
          Text(
            target,
            style: TextStyle(color: Colors.black, fontSize: fontSize * .65),
          ),
        ],
      ),
    );
  }

  Widget _matrix(dom.Element node) {
    final rows = node.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Container(
        decoration: const BoxDecoration(
          border: Border.symmetric(
            vertical: BorderSide(color: Colors.black, width: 1.4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  for (final cell in row.children.where(
                    (e) => e.localName == 'td' || e.localName == 'th',
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        cell.text.trim(),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSize * .88,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _vector(dom.Element node) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              node.text.trim(),
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ),
          const Positioned(
            top: -1,
            child: Text(
              '→',
              style: TextStyle(color: Colors.black, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _isotope(dom.Element node) {
    final mass = node.querySelector('.mass')?.text.trim() ?? '14';
    final element = node.querySelector('.element')?.text.trim() ?? 'C';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.ltr,
        children: [
          Text(
            mass,
            style: TextStyle(color: Colors.black, fontSize: fontSize * .62),
          ),
          Text(
            element,
            style: TextStyle(color: Colors.black, fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  Widget _table(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();

    final tableWidth =
        _cssPercent(table.attributes['style'], 'width') ?? 100;

    var maxColumns = 0;
    for (final row in rows) {
      var count = 0;
      for (final cell in row.children.where(
        (e) => e.localName == 'td' || e.localName == 'th',
      )) {
        count += int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
      }
      if (count > maxColumns) maxColumns = count;
    }
    maxColumns = maxColumns.clamp(1, 12);

    final columnFlex = List<int>.filled(maxColumns, 1);
    final firstRow = rows.first;
    var columnIndex = 0;
    for (final cell in firstRow.children.where(
      (e) => e.localName == 'td' || e.localName == 'th',
    )) {
      final span = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
      final width = _cssPercent(cell.attributes['style'], 'width');
      final flex = width == null ? 1 : width.clamp(1, 100).round();
      for (var i = 0; i < span && columnIndex + i < maxColumns; i++) {
        columnFlex[columnIndex + i] = flex;
      }
      columnIndex += span;
    }

    final tableWidget = Table(
      border: TableBorder.all(color: Colors.black, width: .6),
      columnWidths: {
        for (var i = 0; i < maxColumns; i++)
          i: FlexColumnWidth(columnFlex[i].toDouble()),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (var index = 0; index < maxColumns; index++)
                _tableCell(
                  index < row.children.length
                      ? row.children.where(
                          (e) => e.localName == 'td' || e.localName == 'th',
                        ).elementAt(index)
                      : null,
                ),
            ],
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: (tableWidth / 100).clamp(.2, 1.0),
          alignment: Alignment.centerRight,
          child: tableWidget,
        ),
      ),
    );
  }


  Widget _tableCell(dom.Element? cell) {
    if (cell == null) {
      return const SizedBox.shrink();
    }

    final style = cell.attributes['style'];
    final minHeight = _cssPx(style, 'height') ?? 0;
    final horizontal = _horizontalAlign(style);
    final vertical = _verticalAlign(style);
    final isHeader = cell.localName?.toLowerCase() == 'th';

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFFF3F4F6) : Colors.white,
      ),
      child: Align(
        alignment: _alignment(horizontal, vertical),
        child: DefaultTextStyle(
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize * .9,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
          ),
          child: _inlineFlow(cell),
        ),
      ),
    );
  }



  Alignment _alignment(String horizontal, String vertical) {
    final x = switch (horizontal) {
      'left' => -1.0,
      'center' => 0.0,
      _ => 1.0,
    };
    final y = switch (vertical) {
      'top' => -1.0,
      'bottom' => 1.0,
      _ => 0.0,
    };
    return Alignment(x, y);
  }

  String _horizontalAlign(String? style) {
    final match = RegExp(r'text-align\s*:\s*([a-z-]+)', caseSensitive: false)
        .firstMatch(style ?? '');
    return match?.group(1)?.toLowerCase() ?? 'right';
  }

  String _verticalAlign(String? style) {
    final match = RegExp(r'vertical-align\s*:\s*([a-z-]+)', caseSensitive: false)
        .firstMatch(style ?? '');
    return match?.group(1)?.toLowerCase() ?? 'middle';
  }

  double? _cssPercent(String? style, String property) {
    final match = RegExp(
      property + r'\s*:\s*([0-9.]+)%',
      caseSensitive: false,
    ).firstMatch(style ?? '');
    return double.tryParse(match?.group(1) ?? '');
  }

  double? _cssPx(String? style, String property) {
    final match = RegExp(
      property + r'\s*:\s*([0-9.]+)px',
      caseSensitive: false,
    ).firstMatch(style ?? '');
    return double.tryParse(match?.group(1) ?? '');
  }

  Widget _scientificText(dom.Element node, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        node.text.trim(),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontFamily: 'Arial',
        ),
      ),
    );
  }

  Widget _centered(Widget child) {
    return Align(
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _listItem(dom.Element element, int index, bool ordered) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 18,
          child: Text(
            ordered ? '$index.' : '•',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: fontSize),
          ),
        ),
        Expanded(child: _inlineFlow(element)),
      ],
    );
  }

  Widget _text(String value) {
    return Text(
      value,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        height: 1.35,
      ),
    );
  }

  Set<String> _classes(dom.Element element) {
    return (element.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String _decode(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
  }
}
