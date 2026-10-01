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
            tooltip: 'حفظ السؤال',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          _typeBar(),
          Expanded(child: WebViewWidget(controller: _webView)),
          _optionsPanel(),
        ],
      ),
    );
  }

  Widget _typeBar() {
    return Material(
      color: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
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
    );
  }

  Widget _optionsPanel() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
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
#toolbar,#symbols{display:flex;gap:5px;flex-wrap:wrap;padding:7px;background:#334155;direction:rtl;flex-shrink:0}
#symbols{flex-wrap:nowrap;overflow-x:auto;background:#1e293b}
button{background:#475569;color:#fff;border:1px solid #64748b;border-radius:5px;padding:6px 9px;font-weight:700;font-size:13px;min-width:36px}
button:active{background:#0ea5e9}
#editor{flex:1;overflow:auto;margin:10px;padding:14px 12px 180px;background:#1e293b;border:1px solid #475569;border-radius:6px;outline:none;font-size:18px;line-height:1.9;text-align:right;direction:rtl}
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
</style>
</head>
<body>
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
<div id="editor" contenteditable="true" spellcheck="true"><div><br></div></div>
<script>
const editor=document.getElementById('editor');
function saveSel(){const s=getSelection();if(s.rangeCount)window._r=s.getRangeAt(0).cloneRange();}
function restoreSel(){editor.focus();if(window._r){const s=getSelection();s.removeAllRanges();s.addRange(window._r);}}
function cmd(c,v){restoreSel();document.execCommand(c,false,v||null);saveSel();}
function insert(t){restoreSel();document.execCommand('insertText',false,t);saveSel();}
function insertHtml(h){restoreSel();document.execCommand('insertHTML',false,h);saveSel();}
function fraction(){insertHtml('<span class="eq-frac"><span class="eq-num" contenteditable="true">a</span><span class="eq-den" contenteditable="true">b</span></span>');}
function root(){insertHtml('<span class="eq-root">√<span class="eq-root-body" contenteditable="true">x</span></span>');}
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
