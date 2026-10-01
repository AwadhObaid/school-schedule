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
  });
  final ExamQuestionType type;
  final double marks;
  final int? correctOptionIndex;
  final List<String> options;
}

class _QuestionSettingsSheet extends StatefulWidget {
  const _QuestionSettingsSheet({
    required this.type,
    required this.marks,
    required this.correctOptionIndex,
    required this.options,
  });
  final ExamQuestionType type;
  final double marks;
  final int? correctOptionIndex;
  final List<String> options;

  @override
  State<_QuestionSettingsSheet> createState() => _QuestionSettingsSheetState();
}

class _QuestionSettingsSheetState extends State<_QuestionSettingsSheet> {
  late ExamQuestionType _type;
  late final TextEditingController _marks;
  late int? _correctOptionIndex;
  late final List<TextEditingController> _options;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _marks = TextEditingController(text: widget.marks.toString());
    _correctOptionIndex = widget.correctOptionIndex;
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
  final List<TextEditingController> _options = <TextEditingController>[];
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.multipleChoice;
    _correctOptionIndex = q?.correctOptionIndex;
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
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _type = result.type;
      _marks.text = result.marks.toString();
      _correctOptionIndex = result.correctOptionIndex;
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
table{border-collapse:collapse;width:100%;margin:8px 0}
td,th{border:1px solid #94a3b8;padding:6px;min-width:45px}
#scienceTools{background:#0b1220;display:none}
#scienceTools.visible{display:flex}
#modeBar{display:flex;gap:6px;padding:6px;background:#111827;direction:rtl;flex-shrink:0;border-bottom:1px solid #334155}
#modeBar .mode{background:#334155;border:1px solid #64748b;min-width:0;padding:7px 14px}
#modeBar .mode.active{background:#0ea5e9}
#editor{margin-top:8px}
#scienceTools button{white-space:nowrap;flex:0 0 auto}
.toolTitle{font-size:12px;font-weight:700;color:#cbd5e1;align-self:center;white-space:nowrap}
.science-block{display:inline-flex;align-items:center;vertical-align:middle;margin:2px 4px;padding:2px 3px;border-radius:3px}
.frac{display:inline-flex;flex-direction:column;align-items:center;vertical-align:middle;line-height:1.1}
.frac .num{border-bottom:1.5px solid currentColor;padding:0 5px;min-width:24px;text-align:center}
.frac .den{padding:0 5px;min-width:24px;text-align:center}
.root{display:inline-flex;align-items:stretch;vertical-align:middle}
.root .body{border-top:1.5px solid currentColor;padding:1px 5px;min-width:25px}
.matrix{display:inline-table;border-left:2px solid currentColor;border-right:2px solid currentColor;border-radius:2px;vertical-align:middle}
.matrix td{border:0;padding:2px 7px;min-width:25px;text-align:center}
.limit{display:inline-flex;flex-direction:column;align-items:center;vertical-align:middle;line-height:1.05}
.limit .under{font-size:.72em}
.vector{display:inline-block;position:relative;padding-top:3px}
.vector:before{content:'→';position:absolute;top:-9px;left:50%;transform:translateX(-50%);font-size:.8em}
.chem{font-family:Arial,sans-serif;direction:ltr;unicode-bidi:isolate}
</style>
</head>
<body>
<div id="modeBar">
  <button class="mode active" onclick="setMode('text',this)">✍️ كتابة</button>
  <button class="mode" onclick="setMode('science',this)">🔬 رياضيات وعلوم</button>
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
  <button onclick="matrix()">مصفوفة</button>
  <button onclick="vector()">متجه</button>
  <button onclick="multiLine()">أسطر</button>
  <button onclick="chemFormula()">كيمياء</button>
  <button onclick="chemReaction()">تفاعل</button>
</div>
<div id="editor" contenteditable="true" spellcheck="true"><div><br></div></div>
<script>
const editor=document.getElementById('editor');
function saveSel(){const s=getSelection();if(s.rangeCount)window._r=s.getRangeAt(0).cloneRange();}
function restoreSel(){editor.focus();if(window._r){const s=getSelection();s.removeAllRanges();s.addRange(window._r);}}
function cmd(c,v){restoreSel();document.execCommand(c,false,v||null);saveSel();}
function insert(t){restoreSel();document.execCommand('insertText',false,t);saveSel();}
function insertHtml(h){restoreSel();document.execCommand('insertHTML',false,h);saveSel();}
function fraction(){insertHtml('<span class="science-block frac"><span class="num">a</span><span class="den">b</span></span>');}
function root(){insertHtml('<span class="science-block root">√<span class="body">x</span></span>');}
function power(){insertHtml('<span class="science-block">x<sup>n</sup></span>');}
function subscript(){insertHtml('<span class="science-block">x<sub>n</sub></span>');}
function both(){insertHtml('<span class="science-block">x<sup>n</sup><sub>m</sub></span>');}
function limit(){insertHtml('<span class="science-block limit"><span>lim</span><span class="under">x→a</span></span>');}
function integral(){insert('∫');}
function derivative(){insertHtml('<span class="science-block">d/dx&nbsp; f(x)</span>');}
function sigma(){insertHtml('<span class="science-block limit"><span>Σ</span><span class="under">i=1…n</span></span>');}
function matrix(){insertHtml('<table class="matrix"><tr><td>a₁₁</td><td>a₁₂</td></tr><tr><td>a₂₁</td><td>a₂₂</td></tr></table>');}
function vector(){insertHtml('<span class="science-block vector">v</span>');}
function multiLine(){insertHtml('<div class="science-block">y = ax + b<br>y = mx + c</div>');}
function chemFormula(){insertHtml('<span class="science-block chem">H<sub>2</sub>O + CO<sub>2</sub></span>');}
function chemReaction(){insertHtml('<span class="science-block chem">2H<sub>2</sub> + O<sub>2</sub> → 2H<sub>2</sub>O</span>');}
function setMode(mode,button){
  document.querySelectorAll('#modeBar .mode').forEach(b=>b.classList.remove('active'));
  button.classList.add('active');
  document.body.classList.toggle('science-mode',mode==='science');
  document.body.classList.toggle('text-mode',mode==='text');
  const science=document.getElementById('scienceTools');
  if(science) science.classList.toggle('visible',mode==='science');
  editor.focus();
  saveSel();
}
document.body.classList.add('text-mode');
function mexamGetHTML(){const c=editor.cloneNode(true);c.querySelectorAll('[contenteditable]').forEach(e=>{if(e!==editor)e.removeAttribute('contenteditable')});return c.innerHTML;}
function mexamSetHTML(h){editor.innerHTML=h||'<div><br></div>';saveSel();}
function mexamFocus(){editor.focus();saveSel();}
document.addEventListener('selectionchange',()=>{if(document.activeElement===editor||editor.contains(document.activeElement))saveSel()});
editor.addEventListener('input',saveSel);
editor.addEventListener('keyup',saveSel);
editor.addEventListener('mouseup',saveSel);
editor.addEventListener('touchend',()=>setTimeout(saveSel,0));
</script>
</body>
</html>''';
