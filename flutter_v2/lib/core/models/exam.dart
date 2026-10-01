import 'exam_content_block.dart';
import 'exam_paper_template.dart';

enum ExamQuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  essay,
  matching,
}

extension ExamQuestionTypeX on ExamQuestionType {
  String get label {
    switch (this) {
      case ExamQuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case ExamQuestionType.trueFalse:
        return 'صح أو خطأ';
      case ExamQuestionType.shortAnswer:
        return 'إجابة قصيرة';
      case ExamQuestionType.essay:
        return 'سؤال مقالي';
      case ExamQuestionType.matching:
        return 'مطابقة';
    }
  }

  static ExamQuestionType fromCode(String? value) {
    for (final item in ExamQuestionType.values) {
      if (item.name == value) return item;
    }
    return ExamQuestionType.multipleChoice;
  }
}

class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.options = const <String>[],
    this.correctOptionIndex,
    this.answer = '',
    this.htmlContent = '',
    this.content = const <ExamContentBlock>[],
    this.marks = 1,
  });

  final String id;
  final ExamQuestionType type;
  final String prompt;
  final List<String> options;
  final int? correctOptionIndex;
  final String answer;
  /// Rich HTML body produced by the MExam-style contenteditable editor.
  final String htmlContent;
  final List<ExamContentBlock> content;
  final double marks;

  List<ExamContentBlock> get effectiveContent {
    if (content.isNotEmpty) return content;
    if (prompt.trim().isEmpty) return const <ExamContentBlock>[];
    return <ExamContentBlock>[ExamContentBlock.text(prompt)];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'prompt': prompt,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'answer': answer,
      'htmlContent': htmlContent,
      'content': content.map((item) => item.toJson()).toList(),
      'marks': marks,
    };
  }

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final content = rawContent is List
        ? rawContent
            .whereType<Map>()
            .map(
              (item) => ExamContentBlock.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <ExamContentBlock>[];

    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((item) => item.toString()).toList()
        : <String>[];

    return ExamQuestion(
      id: json['id']?.toString() ?? '',
      type: ExamQuestionTypeX.fromCode(json['type']?.toString()),
      prompt: json['prompt']?.toString() ?? '',
      options: options,
      correctOptionIndex:
          int.tryParse(json['correctOptionIndex']?.toString() ?? ''),
      answer: json['answer']?.toString() ?? '',
      htmlContent: json['htmlContent']?.toString() ?? '',
      content: content,
      marks: double.tryParse(json['marks']?.toString() ?? '') ?? 1,
    );
  }
}

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.subject,
    required this.className,
    this.weekday,
    this.periodId,
    this.durationMinutes = 60,
    this.notes = '',
    this.template = const ExamPaperTemplate(),
    this.questions = const <ExamQuestion>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String subject;
  final String className;
  final int? weekday;
  final String? periodId;
  final int durationMinutes;
  final String notes;
  final ExamPaperTemplate template;
  final List<ExamQuestion> questions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get totalMarks {
    return questions.fold<double>(0, (sum, item) => sum + item.marks);
  }

  Exam copyWith({
    String? title,
    String? subject,
    String? className,
    int? weekday,
    bool clearWeekday = false,
    String? periodId,
    bool clearPeriodId = false,
    int? durationMinutes,
    String? notes,
    ExamPaperTemplate? template,
    List<ExamQuestion>? questions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exam(
      id: id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      weekday: clearWeekday ? null : (weekday ?? this.weekday),
      periodId: clearPeriodId ? null : (periodId ?? this.periodId),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      template: template ?? this.template,
      questions: List.unmodifiable(questions ?? this.questions),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'className': className,
      'weekday': weekday,
      'periodId': periodId,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'template': template.toJson(),
      'questions': questions.map((item) => item.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    final rawTemplate = json['template'];
    final template = rawTemplate is Map
        ? ExamPaperTemplate.fromJson(Map<String, dynamic>.from(rawTemplate))
        : const ExamPaperTemplate();

    final rawQuestions = json['questions'];
    final questions = rawQuestions is List
        ? rawQuestions
            .whereType<Map>()
            .map((item) => ExamQuestion.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ExamQuestion>[];

    DateTime? parseDate(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text);
    }

    return Exam(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      className: json['className']?.toString() ?? '',
      weekday: int.tryParse(json['weekday']?.toString() ?? ''),
      periodId: json['periodId']?.toString(),
      durationMinutes:
          int.tryParse(json['durationMinutes']?.toString() ?? '') ?? 60,
      notes: json['notes']?.toString() ?? '',
      template: template,
      questions: questions,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
