import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/models/exam.dart';

class MexamQuestionEditorSheet extends StatefulWidget {
  const MexamQuestionEditorSheet({this.initial, super.key});
  final ExamQuestion? initial;

  @override
  State<MexamQuestionEditorSheet> createState() => _MexamQuestionEditorSheetState();
}

class _QuestionSettings {
  const _QuestionSettings({
    required this.type,
    required this.marks,
    required this.correctOptionIndex,
    required this.options,
    required this.pageBreakBefore,
  });
  final ExamQuestionType type;
  final double marks;
  final int? correctOptionIndex;
  final List<String> options;
  final bool pageBreakBefore;
}

class _QuestionSettingsSheet extends StatefulWidget {
  const _QuestionSettingsSheet({
    required this.type,
    required this.marks,
    required this.correctOptionIndex,
    required this.options,
    required this.pageBreakBefore,
  });
  final ExamQuestionType type;
  final double marks;
  final int? correctOptionIndex;
  final List<String> options;
  final bool pageBreakBefore;

  @override
  State<_QuestionSettingsSheet> createState() => _QuestionSettingsSheetState();
}

class _QuestionSettingsSheetState extends State<_QuestionSettingsSheet> {
  late ExamQuestionType _type;
  late final TextEditingController _marks;
  late int? _correctOptionIndex;
  late final List<TextEditingController> _options;
  late bool _pageBreakBefore;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _marks = TextEditingController(text: widget.marks.toString());
    _correctOptionIndex = widget.correctOptionIndex;
    _pageBreakBefore = widget.pageBreakBefore;
    _options = widget.options.map((value) => TextEditingController(text: value)).toList();
    if (_type == ExamQuestionType.multipleChoice && _options.length < 2) {
      _options.add(TextEditingController());
      _options.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _marks.dispose();
    for (final item in _options) {
      item.dispose();
    }
    super.dispose();
  }

  static String _letter(int index) {
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    return index < letters.length ? letters[index] : (index + 1).toString();
  }

  void _save() {
    Navigator.pop(
      context,
      _QuestionSettings(
        type: _type,
        marks: double.tryParse(_marks.text.trim()) ?? 1,
        correctOptionIndex: _correctOptionIndex,
        options: _type == ExamQuestionType.multipleChoice
            ? _options.map((e) => e.text.trim()).toList()
            : const <String>[],
        pageBreakBefore: _pageBreakBefore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          children: [
            const Text('إعدادات السؤال', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExamQuestionType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'نوع السؤال',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in ExamQuestionType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  if (_type != ExamQuestionType.multipleChoice) {
                    _correctOptionIndex = null;
                  } else if (_options.length < 2) {
                    _options.add(TextEditingController());
                    _options.add(TextEditingController());
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _marks,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'درجة السؤال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _pageBreakBefore,
              onChanged: (value) => setState(() => _pageBreakBefore = value),
              title: const Text('بدء هذا السؤال في صفحة جديدة'),
              subtitle: const Text('يُستخدم للفصل بين أقسام الاختبار أو الأقسام الطويلة.'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_type == ExamQuestionType.multipleChoice) ...[
              const SizedBox(height: 14),
              const Text('خيارات الإجابة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (var index = 0; index < _options.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: TextField(
                    controller: _options[index],
                    decoration: InputDecoration(
                      labelText: 'الخيار ' + _letter(index),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _options.length >= 6 ? null : () => setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('إضافة خيار'),
              ),
              if (_options.isNotEmpty)
                ...[
                  const SizedBox(height: 8),
                  const Text('الإجابة الصحيحة'),
                  for (var index = 0; index < _options.length; index++)
                    RadioListTile<int>(
                      value: index,
                      groupValue: _correctOptionIndex,
                      onChanged: (value) => setState(() => _correctOptionIndex = value),
                      title: Text(
                        _letter(index) + ' — ' +
                        (_options[index].text.isEmpty ? 'بدون نص' : _options[index].text),
                      ),
                      dense: true,
                    ),
                ],
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }
}


class _MexamQuestionEditorSheetState extends State<MexamQuestionEditorSheet> {
  late final WebViewController _webView;
  late final TextEditingController _marks;
  ExamQuestionType _type = ExamQuestionType.multipleChoice;
  int? _correctOptionIndex;
  bool _pageBreakBefore = false;
  final List<TextEditingController> _options = <TextEditingController>[];
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.multipleChoice;
    _correctOptionIndex = q?.correctOptionIndex;
    _pageBreakBefore = q?.pageBreakBefore ?? false;
    _marks = TextEditingController(text: (q?.marks ?? 1).toString());

    for (final value in q?.options ?? const <String>[]) {
      _options.add(TextEditingController(text: value));
    }
    if (_options.isEmpty && _type == ExamQuestionType.multipleChoice) {
      _options.add(TextEditingController());
      _options.add(TextEditingController());
    }

    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _ready = true;
            final html = widget.initial?.htmlContent ?? _legacyHtml(widget.initial);
            await _webView.runJavaScript('mexamSetHTML(' + jsonEncode(html) + ');');
            await _webView.runJavaScript('mexamFocus();');
          },
        ),
      )
      ..addJavaScriptChannel(
        'MexamBridge',
        onMessageReceived: (message) => _receiveHtml(message.message),
      )
      ..loadHtmlString(_mexamHtml);
  }

  @override
  void dispose() {
    _marks.dispose();
    for (final item in _options) {
      item.dispose();
    }
    super.dispose();
  }

  String _legacyHtml(ExamQuestion? q) {
    if (q == null || q.prompt.trim().isEmpty) return '';
    return '<div>' + const HtmlEscape().convert(q.prompt.trim()) + '</div>';
  }

  Future<void> _confirmClose() async {
    if (!mounted || _saving) return;
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الخروج من محرر السؤال'),
        content: const Text(
          'لم يتم حفظ السؤال بعد. هل تريد الخروج دون حفظ؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('العودة للمحرر'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('الخروج دون حفظ'),
          ),
        ],
      ),
    );
    if (shouldClose == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    await _webView.runJavaScript('MexamBridge.postMessage(mexamGetHTML());');
  }

  void _receiveHtml(String html) {
    final clean = html.trim();
    if (clean.isEmpty || clean == '<div><br></div>') {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب نص السؤال أولاً.')),
      );
      return;
    }

    final options = _type == ExamQuestionType.multipleChoice
        ? _options.map((item) => item.text.trim()).where((item) => item.isNotEmpty).toList()
        : const <String>[];

    Navigator.of(context).pop(
      ExamQuestion(
        id: widget.initial?.id ?? ('question_' + DateTime.now().microsecondsSinceEpoch.toString()),
        type: _type,
        prompt: _plainText(clean),
        htmlContent: clean,
        options: options,
        correctOptionIndex: _type == ExamQuestionType.multipleChoice ? _correctOptionIndex : null,
        answer: widget.initial?.answer ?? '',
        content: widget.initial?.content ?? const [],
        marks: double.tryParse(_marks.text.trim()) ?? 1,
        pageBreakBefore: _pageBreakBefore,
      ),
    );
  }

  String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  void _setType(ExamQuestionType type) {
    setState(() {
      _type = type;
      if (type != ExamQuestionType.multipleChoice) {
        _correctOptionIndex = null;
      } else if (_options.isEmpty) {
        _options.add(TextEditingController());
        _options.add(TextEditingController());
      }
    });
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final item = _options.removeAt(index);
    item.dispose();
    if (_correctOptionIndex == index) {
      _correctOptionIndex = null;
    } else if (_correctOptionIndex != null && _correctOptionIndex! > index) {
      _correctOptionIndex = _correctOptionIndex! - 1;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'إغلاق المحرر',
          onPressed: _saving ? null : _confirmClose,
          icon: const Icon(Icons.close),
        ),
        title: const Text('محرر السؤال — MExam'),
        actions: [
          IconButton(
            tooltip: 'إعدادات السؤال',
            onPressed: _saving ? null : _showQuestionSettings,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'حفظ السؤال',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: WebViewWidget(controller: _webView),
      ),
    );
  }

  Future<void> _showQuestionSettings() async {
    final result = await showModalBottomSheet<_QuestionSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _QuestionSettingsSheet(
        type: _type,
        marks: double.tryParse(_marks.text.trim()) ?? 1,
        correctOptionIndex: _correctOptionIndex,
        options: _options.map((item) => item.text).toList(),
        pageBreakBefore: widget.initial?.pageBreakBefore ?? false,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _type = result.type;
      _marks.text = result.marks.toString();
      _correctOptionIndex = result.correctOptionIndex;
      _pageBreakBefore = result.pageBreakBefore;
      for (final item in _options) {
        item.dispose();
      }
      _options
        ..clear()
        ..addAll(result.options.map((value) => TextEditingController(text: value)));
      if (_type == ExamQuestionType.multipleChoice && _options.length < 2) {
        _options.add(TextEditingController());
        _options.add(TextEditingController());
      }
    });
  }

  Widget _typeBar() {
    return Material(
      color: const Color(0xFF1E293B),
      child: SizedBox(
        height: 48,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('نوع السؤال:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 6),
            for (final type in ExamQuestionType.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: (_) => _setType(type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionsPanel() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _marks,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'درجة السؤال', isDense: true),
                    ),
                  ),
                  if (_type == ExamQuestionType.multipleChoice) ...[
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('خيار'),
                    ),
                  ],
                ],
              ),
              if (_type == ExamQuestionType.multipleChoice)
                ...List.generate(_options.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: index,
                          groupValue: _correctOptionIndex,
                          onChanged: (value) => setState(() => _correctOptionIndex = value),
                        ),
                        Text(_letter(index)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: _options[index],
                            decoration: InputDecoration(
                              labelText: 'الخيار ' + _letter(index),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _options.length > 2 ? () => _removeOption(index) : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }),
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

const String _mexamHtml = r'''<!doctype html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#0f172a;color:#f8fafc;font-family:Arial,'Noto Naskh Arabic',sans-serif}
body{display:flex;flex-direction:column}
#toolbar,#symbols,#scienceTools{display:flex;gap:5px;flex-wrap:nowrap;overflow-x:auto;padding:6px;background:#334155;direction:rtl;flex-shrink:0;min-height:48px;align-items:center}
#symbols{background:#1e293b}
#symbols{display:none}
body.text-mode #symbols{display:flex}
body.science-mode #toolbar{display:none}

button{background:#475569;color:#fff;border:1px solid #64748b;border-radius:5px;padding:6px 9px;font-weight:700;font-size:13px;min-width:36px;height:36px;flex:0 0 auto}
button:active{background:#0ea5e9}
#editor{flex:1;min-height:0;overflow:auto;margin:8px;padding:12px 10px 180px;background:#1e293b;border:1px solid #475569;border-radius:6px;outline:none;font-size:18px;line-height:1.9;text-align:right;direction:rtl}
#editor:focus{border-color:#0ea5e9}
.eq-frac{display:inline-flex;flex-direction:column;vertical-align:middle;align-items:center;margin:0 4px}
.eq-num{border-bottom:2px solid currentColor;padding:0 5px;min-width:20px;text-align:center}
.eq-den{padding:0 5px;min-width:20px;text-align:center}
.eq-root{display:inline-flex;align-items:stretch;vertical-align:middle;margin:0 3px}
.eq-root-body{border-top:2px solid currentColor;padding:1px 5px;min-width:20px}
sup{font-size:.72em;vertical-align:super}
sub{font-size:.72em;vertical-align:sub}
table{border-collapse:collapse;width:100%;margin:8px 0;table-layout:fixed}
td,th{border:1px solid #94a3b8;padding:6px;min-width:45px;position:relative;vertical-align:middle;word-break:break-word}
#tableTools{display:none;gap:5px;flex-wrap:nowrap;overflow-x:auto;padding:6px;background:#172554;border-bottom:1px solid #334155;direction:rtl;flex-shrink:0;align-items:center}
#tableTools.visible{display:flex}
#tableTools .toolTitle{color:#bfdbfe}
#tableTools button{height:34px}
#tableTools .danger{background:#7f1d1d;border-color:#991b1b}
#tableTools .accent{background:#075985;border-color:#0369a1}
.table-selected{outline:2px solid #38bdf8!important;outline-offset:2px}
.table-cell-selected{background:rgba(56,189,248,.14)!important;box-shadow:inset 0 0 0 2px #38bdf8}
#tableDialog{display:none;position:fixed;inset:0;z-index:50;background:rgba(2,6,23,.72);align-items:center;justify-content:center;padding:18px}
#tableDialog.visible{display:flex}
#tableDialogCard{width:min(420px,94vw);background:#1e293b;border:1px solid #64748b;border-radius:10px;padding:16px;box-shadow:0 18px 50px rgba(0,0,0,.45);direction:rtl}
#tableDialogCard h3{margin:0 0 12px;font-size:18px}
.tableGrid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.tableField{display:flex;flex-direction:column;gap:5px}
.tableField label{font-size:12px;color:#cbd5e1}
.tableField input{height:38px;border:1px solid #64748b;border-radius:6px;background:#0f172a;color:#fff;padding:0 9px;font-size:15px}
.tableDialogActions{display:flex;gap:8px;margin-top:14px}
.tableDialogActions button{flex:1}
.table-handle-col{position:absolute;right:-4px;top:0;width:9px;height:100%;cursor:col-resize;z-index:4}
.table-handle-row{position:absolute;left:0;bottom:-4px;width:100%;height:9px;cursor:row-resize;z-index:4}
#scienceTools{background:#0b1220;display:none}
#scienceTools.visible{display:flex}
#modeBar{display:flex;gap:6px;padding:6px;background:#111827;direction:rtl;flex-shrink:0;border-bottom:1px solid #334155}
#modeBar .mode{background:#334155;border:1px solid #64748b;min-width:0;padding:7px 14px}
#modeBar .mode.active{background:#0ea5e9}
#editor{margin-top:8px}
#scienceTools button{white-space:nowrap;flex:0 0 auto}
.toolTitle{font-size:12px;font-weight:700;color:#cbd5e1;align-self:center;white-space:nowrap}
.science-block{display:inline-flex;align-items:center;vertical-align:middle;margin:2px 4px;padding:2px 3px;border-radius:3px}
.science-block[contenteditable="false"]{user-select:none}
.block-editable{outline:none;min-width:18px}
.block-editable:focus{outline:1px dashed #38bdf8;border-radius:3px;background:rgba(56,189,248,.08)}
.frac{display:inline-flex;flex-direction:column;align-items:center;vertical-align:middle;line-height:1.1}
.frac .num{border-bottom:1.5px solid currentColor;padding:0 7px;min-width:30px;min-height:24px;text-align:center;outline:none}
.frac .den{padding:0 7px;min-width:30px;min-height:24px;text-align:center;outline:none}
.editable-part:focus{outline:1px dashed #38bdf8;border-radius:3px;background:rgba(56,189,248,.08)}
.root{display:inline-flex;align-items:stretch;vertical-align:middle}
.root .body{border-top:1.5px solid currentColor;padding:2px 7px;min-width:30px;min-height:24px;outline:none}
.matrix{display:inline-table;border-left:2px solid currentColor;border-right:2px solid currentColor;border-radius:2px;vertical-align:middle;width:auto}
.determinant{border-left:2px solid currentColor;border-right:2px solid currentColor}
.matrix td{border:0;padding:4px 8px;min-width:34px;min-height:26px;text-align:center;outline:none}
.matrix td:focus{outline:1px dashed #38bdf8;background:rgba(56,189,248,.08)}
.limit{display:inline-flex;flex-direction:column;align-items:center;vertical-align:middle;line-height:1.05}
.limit .under{font-size:.72em;outline:none;min-width:28px}
.limit .under:focus{outline:1px dashed #38bdf8;border-radius:3px}
.vector{display:inline-block;position:relative;padding-top:3px}
.vector:before{content:'→';position:absolute;top:-9px;left:50%;transform:translateX(-50%);font-size:.8em}
.chem{font-family:Arial,sans-serif;direction:ltr;unicode-bidi:isolate}
.chem sub,.chem sup{font-size:.68em;line-height:0}
.chem .charge{font-size:.68em;vertical-align:super;position:relative;top:-.15em}
.isotope{display:inline-flex;align-items:flex-start;direction:ltr;font-family:Arial,sans-serif}
.isotope .mass{font-size:.62em;line-height:1;min-width:12px}
.isotope .element{font-size:1em}
.science-template{display:inline-block;direction:ltr;padding:2px 6px;margin:2px;border-radius:4px}
.physics-unit{font-family:Arial,sans-serif;direction:ltr;unicode-bidi:isolate}
.science-table{display:inline-table;width:auto;margin:4px}
.science-table td{min-width:42px;padding:5px 8px;border:1px solid #94a3b8;text-align:center;outline:none}
.science-table td:focus{outline:1px dashed #38bdf8;background:rgba(56,189,248,.08)}
</style>
</head>
<body>
<div id="modeBar">
  <button class="mode active" onclick="setMode('text',this)">✍️ كتابة</button>
  <button class="mode" onclick="setMode('science',this)">🔬 رياضيات وعلوم</button>
</div>
<div id="tableTools">
  <span class="toolTitle">أدوات الجدول</span>
  <button class="accent" onclick="tableAddRow()">＋ صف</button>
  <button class="accent" onclick="tableAddColumn()">＋ عمود</button>
  <button onclick="tableDeleteRow()">− صف</button>
  <button onclick="tableDeleteColumn()">− عمود</button>
  <button onclick="tableMerge()">دمج</button>
  <button onclick="tableSplit()">فصل</button>
  <button onclick="tableProperties()">خصائص</button>
  <button class="danger" onclick="tableDelete()">حذف الجدول</button>
</div>
<div id="toolbar">
<button onclick="cmd('bold')">B</button>
<button onclick="cmd('italic')">I</button>
<button onclick="cmd('underline')">U</button>
<button onclick="cmd('justifyRight')">يمين</button>
<button onclick="cmd('justifyCenter')">وسط</button>
<button onclick="cmd('justifyLeft')">يسار</button>
<button onclick="cmd('insertUnorderedList')">• قائمة</button>
<button onclick="cmd('insertOrderedList')">1. قائمة</button>
<button onclick="insertTable()">▦ جدول</button>
<button onclick="cmd('undo')">↶</button>
<button onclick="cmd('redo')">↷</button>
<button onclick="cmd('removeFormat')">تنظيف</button>
</div>
<div id="symbols">
<button onclick="insert('²')">x²</button><button onclick="insert('₁')">x₁</button>
<button onclick="insert('√')">√</button><button onclick="insert('π')">π</button>
<button onclick="insert('∞')">∞</button><button onclick="insert('±')">±</button>
<button onclick="insert('≤')">≤</button><button onclick="insert('≥')">≥</button>
<button onclick="insert('≠')">≠</button><button onclick="insert('≈')">≈</button>
<button onclick="insert('α')">α</button><button onclick="insert('β')">β</button>
<button onclick="insert('γ')">γ</button><button onclick="insert('θ')">θ</button>
<button onclick="insert('λ')">λ</button><button onclick="insert('μ')">μ</button>
<button onclick="insert('ρ')">ρ</button><button onclick="insert('Ω')">Ω</button>
<button onclick="insert('Σ')">Σ</button><button onclick="insert('∫')">∫</button>
<button onclick="insert('Δ')">Δ</button><button onclick="fraction()">a/b</button>
<button onclick="root()">√x</button>
</div>
<div id="scienceTools">
  <span class="toolTitle">الرياضيات والعلوم المتقدمة</span>
  <button onclick="fraction()">كسر</button>
  <button onclick="root()">جذر</button>
  <button onclick="power()">xⁿ</button>
  <button onclick="subscript()">xₙ</button>
  <button onclick="both()">xⁿₘ</button>
  <button onclick="limit()">lim</button>
  <button onclick="integral()">∫</button>
  <button onclick="derivative()">d/dx</button>
  <button onclick="sigma()">Σ</button>
  <button onclick="matrix()">مصفوفة 2×2</button>
  <button onclick="matrix3()">مصفوفة 3×3</button>
  <button onclick="determinant()">محدد</button>
  <button onclick="vector()">متجه</button>
  <button onclick="multiLine()">أسطر</button>
  <button onclick="chemFormula()">صيغة كيميائية</button>
  <button onclick="chemReaction()">تفاعل كيميائي</button>
  <button onclick="chemIon()">أيون</button>
  <button onclick="isotope()">نظير</button>
  <button onclick="chemArrow()">⇌ تفاعل</button>
  <button onclick="physicsVector()">متجه فيزيائي</button>
  <button onclick="physicsUnit()">وحدة</button>
  <button onclick="quadratic()">تربيعية</button>
  <button onclick="pythagoras()">فيثاغورس</button>
  <button onclick="table2()">جدول 2×2</button>
</div>
<div id="tableDialog">
  <div id="tableDialogCard">
    <h3 id="tableDialogTitle">إضافة جدول</h3>
    <div class="tableGrid">
      <div class="tableField"><label>عدد الصفوف</label><input id="tableRowsInput" type="number" min="1" max="30" value="3"></div>
      <div class="tableField"><label>عدد الأعمدة</label><input id="tableColsInput" type="number" min="1" max="12" value="2"></div>
      <div class="tableField"><label>عرض الجدول %</label><input id="tableWidthInput" type="number" min="20" max="100" value="100"></div>
      <div class="tableField"><label>ارتفاع الصف px</label><input id="tableHeightInput" type="number" min="20" max="240" value="36"></div>
    </div>
    <div class="tableDialogActions">
      <button onclick="closeTableDialog()">إلغاء</button>
      <button class="accent" onclick="createTableFromDialog()">إدراج الجدول</button>
    </div>
  </div>
</div>
<div id="editor" contenteditable="true" spellcheck="true"><div><br></div></div>
<script>
const editor=document.getElementById('editor');
function setMode(mode,button){
  const isScience=mode==='science';
  document.body.classList.toggle('science-mode',isScience);
  document.body.classList.toggle('text-mode',!isScience);
  document.querySelectorAll('#modeBar .mode').forEach(function(item){
    item.classList.toggle('active',item===button);
  });
  if(isScience){
    document.getElementById('scienceTools').classList.add('visible');
    document.getElementById('toolbar').style.display='none';
    document.getElementById('symbols').style.display='none';
  }else{
    document.getElementById('scienceTools').classList.remove('visible');
    document.getElementById('toolbar').style.display='flex';
    document.getElementById('symbols').style.display='flex';
  }
  saveSel();
}
function saveSel(){const s=getSelection();if(s.rangeCount)window._r=s.getRangeAt(0).cloneRange();}
function restoreSel(){editor.focus();if(window._r){const s=getSelection();s.removeAllRanges();s.addRange(window._r);}}
function cmd(c,v){restoreSel();document.execCommand(c,false,v||null);saveSel();}
function insert(t){restoreSel();document.execCommand('insertText',false,t);saveSel();}
function insertHtml(h){restoreSel();document.execCommand('insertHTML',false,h);saveSel();}
let scienceId=0;
function focusElement(el){
  if(!el) return;
  const range=document.createRange();
  range.selectNodeContents(el);
  range.collapse(false);
  const sel=getSelection();
  sel.removeAllRanges();
  sel.addRange(range);
  el.focus();
  saveSel();
}
function insertScience(html, partSelector){
  const id='science_' + (++scienceId);
  const tagged=html.replace('data-science-id=""','data-science-id="'+id+'"');
  insertHtml(tagged);
  const block=editor.querySelector('[data-science-id="'+id+'"]');
  if(block){
    block.removeAttribute('data-science-id');
    focusElement(partSelector ? block.querySelector(partSelector) : block);
  }
}
function fraction(){
  insertScience('<span class="science-block frac" data-science-id=""><span class="num editable-part" contenteditable="true">a</span><span class="den editable-part" contenteditable="true">b</span></span>','.num');
}
function root(){
  insertScience('<span class="science-block root" data-science-id="">√<span class="body editable-part" contenteditable="true">x</span></span>','.body');
}
function power(){
  insertScience('<span class="science-block" data-science-id="">x<sup class="block-editable" contenteditable="true">n</sup></span>','sup');
}
function subscript(){
  insertScience('<span class="science-block" data-science-id="">x<sub class="block-editable" contenteditable="true">n</sub></span>','sub');
}
function both(){
  insertScience('<span class="science-block" data-science-id="">x<sup class="block-editable" contenteditable="true">n</sup><sub class="block-editable" contenteditable="true">m</sub></span>','sup');
}
function limit(){
  insertScience('<span class="science-block limit" data-science-id=""><span>lim</span><span class="under block-editable" contenteditable="true">x→a</span></span>','.under');
}
function integral(){
  insertScience('<span class="science-block limit" data-science-id=""><span class="under block-editable" contenteditable="true">b</span><span style="font-size:2em;line-height:.7">∫</span><span class="under block-editable" contenteditable="true">a</span></span>','.under');
}
function derivative(){
  insertScience('<span class="science-block" data-science-id="">d/dx&nbsp;<span class="block-editable" contenteditable="true">f(x)</span></span>','.block-editable');
}
function sigma(){
  insertScience('<span class="science-block limit" data-science-id=""><span class="under block-editable" contenteditable="true">i=1</span><span style="font-size:1.7em">Σ</span><span class="under block-editable" contenteditable="true">n</span></span>','.under');
}
function matrix(){
  insertScience('<table class="matrix" data-science-id=""><tr><td contenteditable="true">a₁₁</td><td contenteditable="true">a₁₂</td></tr><tr><td contenteditable="true">a₂₁</td><td contenteditable="true">a₂₂</td></tr></table><span> </span>','td');
}
function matrix3(){
  insertScience('<table class="matrix" data-science-id=""><tr><td contenteditable="true">a₁₁</td><td contenteditable="true">a₁₂</td><td contenteditable="true">a₁₃</td></tr><tr><td contenteditable="true">a₂₁</td><td contenteditable="true">a₂₂</td><td contenteditable="true">a₂₃</td></tr><tr><td contenteditable="true">a₃₁</td><td contenteditable="true">a₃₂</td><td contenteditable="true">a₃₃</td></tr></table><span> </span>','td');
}
function determinant(){
  insertScience('<table class="matrix determinant" data-science-id=""><tr><td contenteditable="true">a</td><td contenteditable="true">b</td></tr><tr><td contenteditable="true">c</td><td contenteditable="true">d</td></tr></table><span> </span>','td');
}
function vector(){
  insertScience('<span class="science-block vector" data-science-id=""><span class="block-editable" contenteditable="true">v</span></span>','.block-editable');
}
function multiLine(){
  insertScience('<div class="science-block" data-science-id=""><span class="block-editable" contenteditable="true">y = ax + b</span><br><span class="block-editable" contenteditable="true">y = mx + c</span></div>','.block-editable');
}
function chemFormula(){
  insertScience('<span class="science-block chem" data-science-id=""><span class="block-editable" contenteditable="true">H<sub>2</sub>O + CO<sub>2</sub></span></span>','.block-editable');
}
function chemReaction(){
  insertScience('<span class="science-block chem" data-science-id=""><span class="block-editable" contenteditable="true">2H<sub>2</sub> + O<sub>2</sub> → 2H<sub>2</sub>O</span></span>','.block-editable');
}
function chemIon(){
  insertScience('<span class="science-block chem" data-science-id=""><span class="block-editable" contenteditable="true">SO<sub>4</sub><sup class="charge">2−</sup></span></span>','.block-editable');
}
function isotope(){
  insertScience('<span class="science-block isotope" data-science-id=""><span class="mass block-editable" contenteditable="true">14</span><span class="element block-editable" contenteditable="true">C</span></span>','.element');
}
function chemArrow(){
  insertScience('<span class="science-block chem" data-science-id=""><span class="block-editable" contenteditable="true">A ⇌ B</span></span>','.block-editable');
}
function physicsVector(){
  insertScience('<span class="science-block vector" data-science-id=""><span class="block-editable" contenteditable="true">F</span></span>','.block-editable');
}
function physicsUnit(){
  insertScience('<span class="science-block physics-unit" data-science-id=""><span class="block-editable" contenteditable="true">m·s⁻²</span></span>','.block-editable');
}
function quadratic(){
  insertScience('<span class="science-template" data-science-id="">ax² + bx + c = 0</span>');
}
function pythagoras(){
  insertScience('<span class="science-template" data-science-id="">a² + b² = c²</span>');
}
function table2(){
  insertScience('<table class="science-table" data-science-id=""><tr><td contenteditable="true">القيمة</td><td contenteditable="true">الوحدة</td></tr><tr><td contenteditable="true"></td><td contenteditable="true"></td></tr></table><span> </span>','td');
}
let activeTable=null;
let activeCell=null;
let selectedCells=[];
let resizeState=null;

function clearTableSelection(){
  selectedCells.forEach(c=>c.classList.remove('table-cell-selected'));
  selectedCells=[];
}

function showTableTools(table){
  activeTable=table;
  document.querySelectorAll('table.table-selected').forEach(t=>t.classList.remove('table-selected'));
  if(table) {
    table.classList.add('table-selected');
    document.getElementById('tableTools').classList.add('visible');
  } else {
    document.getElementById('tableTools').classList.remove('visible');
  }
}

function selectTableCell(cell, additive){
  if(!cell) return;
  const table=cell.closest('table');
  if(!table) return;
  if(!additive) clearTableSelection();
  if(!selectedCells.includes(cell)){
    selectedCells.push(cell);
    cell.classList.add('table-cell-selected');
  }
  activeCell=cell;
  showTableTools(table);
  saveSel();
}

function normalizeTable(table){
  if(!table) return;
  table.style.tableLayout='fixed';
  if(!table.style.width) table.style.width='100%';
  table.querySelectorAll('td,th').forEach(cell=>{
    cell.setAttribute('contenteditable','true');
    if(!cell.style.minHeight) cell.style.minHeight='30px';
    if(!cell.style.padding) cell.style.padding='6px';
  });
  installTableHandles(table);
}

function installTableHandles(table){
  table.querySelectorAll('td,th').forEach(cell=>{
    if(!cell.querySelector(':scope > .table-handle-col')){
      const col=document.createElement('span');
      col.className='table-handle-col';
      col.setAttribute('contenteditable','false');
      cell.appendChild(col);
    }
    if(!cell.querySelector(':scope > .table-handle-row')){
      const row=document.createElement('span');
      row.className='table-handle-row';
      row.setAttribute('contenteditable','false');
      cell.appendChild(row);
    }
  });
}

function stripTableHandles(root){
  root.querySelectorAll('.table-handle-col,.table-handle-row').forEach(h=>h.remove());
}

function tableCellInfo(cell){
  const row=cell.parentElement;
  const table=cell.closest('table');
  return {table:table,row:row,rowIndex:row ? row.rowIndex : -1,colIndex:cell.cellIndex};
}

function insertTable(){
  openTableDialog();
}

function openTableDialog(){
  document.getElementById('tableDialogTitle').textContent='إضافة جدول';
  document.getElementById('tableDialog').classList.add('visible');
  setTimeout(()=>document.getElementById('tableRowsInput').focus(),0);
}

function closeTableDialog(){
  document.getElementById('tableDialog').classList.remove('visible');
}

function createTableFromDialog(){
  const rows=Math.max(1,Math.min(30,parseInt(document.getElementById('tableRowsInput').value||'3',10)));
  const cols=Math.max(1,Math.min(12,parseInt(document.getElementById('tableColsInput').value||'2',10)));
  const width=Math.max(20,Math.min(100,parseInt(document.getElementById('tableWidthInput').value||'100',10)));
  const height=Math.max(20,Math.min(240,parseInt(document.getElementById('tableHeightInput').value||'36',10)));
  let html='<table style="width:'+width+'%"><tbody>';
  for(let r=0;r<rows;r++){
    html+='<tr style="height:'+height+'px">';
    for(let c=0;c<cols;c++){
      html+=r===0?'<th style="height:'+height+'px">عنوان</th>':'<td style="height:'+height+'px"></td>';
    }
    html+='</tr>';
  }
  html+='</tbody></table><p><br></p>';
  closeTableDialog();
  insertHtml(html);
  const tables=editor.querySelectorAll('table');
  const table=tables[tables.length-1];
  if(table){
    normalizeTable(table);
    selectTableCell(table.rows[0].cells[0],false);
    focusElement(table.rows[0].cells[0]);
  }
}

function selectedTable(){
  return activeTable || (activeCell ? activeCell.closest('table') : null);
}

function tableAddRow(){
  const table=selectedTable();
  if(!table) return;
  const ref=activeCell ? activeCell.parentElement : table.rows[table.rows.length-1];
  const row=table.insertRow(ref ? ref.rowIndex+1 : -1);
  const colCount=Math.max(1, table.rows[0] ? table.rows[0].cells.length : 1);
  for(let i=0;i<colCount;i++){
    const cell=row.insertCell(-1);
    cell.innerHTML='<br>';
    cell.style.height='30px';
  }
  normalizeTable(table);
  selectTableCell(row.cells[Math.min(activeCell ? activeCell.cellIndex : 0,row.cells.length-1)],false);
}

function tableDeleteRow(){
  const table=selectedTable();
  if(!table || table.rows.length<=1) return;
  const index=activeCell ? activeCell.parentElement.rowIndex : table.rows.length-1;
  table.deleteRow(index);
  normalizeTable(table);
  const row=table.rows[Math.min(index,table.rows.length-1)];
  selectTableCell(row.cells[0],false);
}

function tableAddColumn(){
  const table=selectedTable();
  if(!table) return;
  const index=activeCell ? activeCell.cellIndex+1 : (table.rows[0]?.cells.length||0);
  for(const row of table.rows){
    const cell=row.insertCell(Math.min(index,row.cells.length));
    cell.innerHTML='<br>';
    cell.style.height=(row.style.height||'30px');
  }
  normalizeTable(table);
  const row=table.rows[activeCell ? activeCell.parentElement.rowIndex : 0];
  selectTableCell(row.cells[Math.min(index,row.cells.length-1)],false);
}

function tableDeleteColumn(){
  const table=selectedTable();
  if(!table) return;
  const colCount=table.rows[0]?.cells.length||0;
  if(colCount<=1) return;
  const index=activeCell ? activeCell.cellIndex : colCount-1;
  for(const row of table.rows){
    if(row.cells[index]) row.deleteCell(index);
  }
  normalizeTable(table);
  const row=table.rows[Math.min(activeCell ? activeCell.parentElement.rowIndex : 0,table.rows.length-1)];
  selectTableCell(row.cells[Math.min(index,row.cells.length-1)],false);
}

function tableMerge(){
  if(selectedCells.length<2) return;
  const table=selectedCells[0].closest('table');
  if(!selectedCells.every(c=>c.closest('table')===table)) return;
  const cells=selectedCells.slice().sort((a,b)=>a.parentElement.rowIndex-b.parentElement.rowIndex || a.cellIndex-b.cellIndex);
  const first=cells[0];
  const sameRow=cells.every(c=>c.parentElement===first.parentElement);
  const sameCol=cells.every(c=>c.cellIndex===first.cellIndex);
  if(!sameRow && !sameCol) return;
  if(cells.length>1){
    if(sameRow){
      const max=Math.max(...cells.map(c=>c.cellIndex));
      const contiguous=cells.length===max-first.cellIndex+1;
      if(!contiguous) return;
      first.colSpan=cells.length;
    }else{
      const max=Math.max(...cells.map(c=>c.parentElement.rowIndex));
      const contiguous=cells.length===max-first.parentElement.rowIndex+1;
      if(!contiguous) return;
      first.rowSpan=cells.length;
    }
    for(let i=1;i<cells.length;i++){
      if(cells[i]!==first) first.innerHTML+=(first.innerHTML.trim()?'<br>':'')+cells[i].innerHTML;
      cells[i].remove();
    }
    normalizeTable(table);
    selectTableCell(first,false);
  }
}

function tableSplit(){
  if(!activeCell) return;
  const cell=activeCell;
  const table=cell.closest('table');
  const row=cell.parentElement;
  const colspan=cell.colSpan||1;
  const rowspan=cell.rowSpan||1;
  if(colspan>1){
    cell.colSpan=1;
    for(let i=1;i<colspan;i++){
      const newCell=document.createElement(cell.tagName.toLowerCase());
      newCell.innerHTML='<br>';
      newCell.style.height=cell.style.height||'30px';
      row.insertBefore(newCell,cell.nextSibling);
    }
  }
  if(rowspan>1){
    cell.rowSpan=1;
    const start=row.rowIndex+1;
    for(let r=0;r<rowspan-1;r++){
      const target=table.rows[start+r];
      if(!target) break;
      const newCell=document.createElement(cell.tagName.toLowerCase());
      newCell.innerHTML='<br>';
      newCell.style.height=target.style.height||'30px';
      target.insertBefore(newCell, target.cells[Math.min(cell.cellIndex,target.cells.length)]);
    }
  }
  normalizeTable(table);
  selectTableCell(cell,false);
}

function tableDelete(){
  const table=selectedTable();
  if(!table) return;
  table.remove();
  activeTable=null;
  activeCell=null;
  clearTableSelection();
  document.getElementById('tableTools').classList.remove('visible');
}

function tableProperties(){
  const table=selectedTable();
  if(!table) return;
  document.getElementById('tableDialogTitle').textContent='خصائص الجدول';
  document.getElementById('tableRowsInput').value=table.rows.length;
  document.getElementById('tableColsInput').value=table.rows[0]?.cells.length||1;
  document.getElementById('tableWidthInput').value=parseInt(table.style.width)||100;
  document.getElementById('tableHeightInput').value=parseInt(table.rows[0]?.style.height)||36;
  document.getElementById('tableDialog').classList.add('visible');
  const action=document.querySelector('#tableDialogCard .tableDialogActions .accent');
  action.textContent='تطبيق';
  action.onclick=applyTableProperties;
}

function applyTableProperties(){
  const table=selectedTable();
  if(!table) return;
  const width=Math.max(20,Math.min(100,parseInt(document.getElementById('tableWidthInput').value||'100',10)));
  const height=Math.max(20,Math.min(240,parseInt(document.getElementById('tableHeightInput').value||'36',10)));
  table.style.width=width+'%';
  for(const row of table.rows) row.style.height=height+'px';
  normalizeTable(table);
  const action=document.querySelector('#tableDialogCard .tableDialogActions .accent');
  action.textContent='إدراج الجدول';
  action.onclick=createTableFromDialog;
  closeTableDialog();
}

function resizeColumn(cell,delta){
  const table=cell.closest('table');
  if(!table) return;
  const index=cell.cellIndex;
  const row=cell.parentElement;
  const base=Math.max(45,cell.getBoundingClientRect().width);
  const next=Math.max(45,base+delta);
  const total=Math.max(1,table.getBoundingClientRect().width);
  const pct=Math.min(90,Math.max(5,(next/total)*100));
  for(const r of table.rows){
    const c=r.cells[index];
    if(c && (c.colSpan||1)===1) c.style.width=pct+'%';
  }
}

function resizeRow(cell,delta){
  const row=cell.parentElement;
  const next=Math.max(24,Math.max(24,row.getBoundingClientRect().height)+delta);
  row.style.height=next+'px';
  for(const c of row.cells) c.style.height=next+'px';
}

editor.addEventListener('click',function(e){
  const cell=e.target.closest && e.target.closest('td,th');
  if(cell && editor.contains(cell)){
    selectTableCell(cell,e.shiftKey);
    return;
  }
  if(!e.target.closest || !e.target.closest('table')){
    showTableTools(null);
    clearTableSelection();
  }
});

editor.addEventListener('dblclick',function(e){
  const cell=e.target.closest && e.target.closest('td,th');
  if(cell) focusElement(cell);
});

editor.addEventListener('pointerdown',function(e){
  const cell=e.target.closest && e.target.closest('td,th');
  if(!cell || !editor.contains(cell)) return;
  const rect=cell.getBoundingClientRect();
  const nearRight=Math.abs(e.clientX-rect.right)<10;
  const nearBottom=Math.abs(e.clientY-rect.bottom)<10;
  if(nearRight && (cell.colSpan||1)===1){
    resizeState={kind:'col',cell:cell,last:e.clientX};
    e.preventDefault();
  }else if(nearBottom){
    resizeState={kind:'row',cell:cell,last:e.clientY};
    e.preventDefault();
  }
});

window.addEventListener('pointermove',function(e){
  if(!resizeState) return;
  if(resizeState.kind==='col'){
    const delta=e.clientX-resizeState.last;
    if(Math.abs(delta)>=1){resizeColumn(resizeState.cell,delta);resizeState.last=e.clientX;}
  }else{
    const delta=e.clientY-resizeState.last;
    if(Math.abs(delta)>=1){resizeRow(resizeState.cell,delta);resizeState.last=e.clientY;}
  }
});
window.addEventListener('pointerup',function(){resizeState=null;});

editor.addEventListener('keydown',function(e){
  const target=e.target;
  if(!(target instanceof HTMLElement)) return;
  if((target.classList.contains('editable-part')||target.classList.contains('block-editable')) &&
     e.key==='Backspace' && target.textContent.trim()===''){
    e.preventDefault();
    const block=target.closest('.science-block,.frac,.root,.matrix');
    if(block){
      block.remove();
      saveSel();
    }
  }
});
editor.addEventListener('keyup',saveSel);
editor.addEventListener('mouseup',saveSel);
editor.addEventListener('touchend',()=>setTimeout(saveSel,0));

editor.addEventListener('keydown',function(e){
  if(e.key==='Tab' && activeCell){
    const table=activeCell.closest('table');
    const cells=Array.from(table.querySelectorAll('td,th'));
    const i=cells.indexOf(activeCell);
    if(i>=0){
      e.preventDefault();
      const next=cells[i+1];
      if(next){
        selectTableCell(next,false);
        focusElement(next);
      }else{
        tableAddRow();
        focusElement(activeCell);
      }
    }
  }
});

document.getElementById('tableDialog').addEventListener('click',function(e){
  if(e.target===this) closeTableDialog();
});

document.addEventListener('click',function(e){
  if(!e.target.closest('table') &&
     !e.target.closest('#tableTools') &&
     !e.target.closest('#tableDialog')){
    showTableTools(null);
    clearTableSelection();
  }
});

document.getElementById('tableRowsInput').addEventListener('keydown',function(e){
  if(e.key==='Enter') createTableFromDialog();
});
document.getElementById('tableColsInput').addEventListener('keydown',function(e){
  if(e.key==='Enter') createTableFromDialog();
});

function mexamGetHTML(){
  const c=editor.cloneNode(true);
  stripTableHandles(c);
  c.querySelectorAll('[contenteditable]').forEach(function(e){
    if(e!==c) e.removeAttribute('contenteditable');
  });
  c.querySelectorAll('table').forEach(function(t){
    t.classList.remove('table-selected');
  });
  c.querySelectorAll('.table-cell-selected').forEach(function(e){
    e.classList.remove('table-cell-selected');
  });
  return c.innerHTML;
}

function mexamSetHTML(h){
  editor.innerHTML=h||'<div><br></div>';
  editor.querySelectorAll('table').forEach(normalizeTable);
  saveSel();
}

function mexamFocus(){
  editor.focus();
  saveSel();
}

document.addEventListener('selectionchange',function(){
  if(document.activeElement===editor || editor.contains(document.activeElement)){
    saveSel();
  }
});
editor.addEventListener('input',saveSel);
</script>
</body>
</html>''';