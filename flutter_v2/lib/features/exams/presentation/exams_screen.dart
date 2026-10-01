import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/exam.dart';
import '../../../core/storage/exam_store.dart';
import 'exam_editor_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final _store = ExamStore();
  List<Exam> _exams = <Exam>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exams = await _store.load();
    if (!mounted) return;
    setState(() {
      _exams = exams;
      _loading = false;
    });
  }

  Future<void> _edit([Exam? exam]) async {
    final result = await Navigator.of(context).push<Exam>(
      MaterialPageRoute(
        builder: (_) => ExamEditorScreen(
          controller: widget.controller,
          store: _store,
          initial: exam,
        ),
      ),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الاختبار'),
        content: Text.rich(
          TextSpan(
            text: 'هل تريد حذف الاختبار «',
            children: [
              TextSpan(text: exam.title),
              const TextSpan(text: '»؟'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final next = _exams.where((item) => item.id != exam.id).toList();
    await _store.save(next);
    if (!mounted) return;
    setState(() => _exams = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبارات'),
        actions: [
          IconButton(
            onPressed: () => _edit(),
            tooltip: 'اختبار جديد',
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('اختبار جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
              ? _EmptyState(onCreate: () => _edit())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _exams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final exam = _exams[index];
                    final summary = StringBuffer()
                      ..write(exam.subject)
                      ..write(' • ')
                      ..write(exam.className.isEmpty ? 'بدون صف' : exam.className)
                      ..write(' • ')
                      ..write(exam.questions.length)
                      ..write(' سؤال • ')
                      ..write(exam.totalMarks)
                      ..write(' درجة');
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.assignment_outlined),
                        ),
                        title: Text(
                          exam.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(summary.toString()),
                        onTap: () => _edit(exam),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _edit(exam);
                            if (value == 'delete') _delete(exam);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد اختبارات محفوظة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنشئ اختبارًا واربطه بالمادة والصف والحصة من جدولك.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء أول اختبار'),
            ),
          ],
        ),
      ),
    );
  }
}
