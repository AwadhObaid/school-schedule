import 'package:flutter_test/flutter_test.dart';

import 'package:schedule/core/models/exam.dart';
import 'package:schedule/core/models/exam_content_block.dart';
import 'package:schedule/core/models/exam_paper_template.dart';

void main() {
  group('Exam rich content', () {
    test('round trips text and equation blocks', () {
      const source = ExamQuestion(
        id: 'q1',
        type: ExamQuestionType.multipleChoice,
        prompt: 'حل المعادلة',
        content: [
          ExamContentBlock.text('حل المعادلة'),
          ExamContentBlock.equation(
            r'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
          ),
        ],
        options: ['أ', 'ب'],
        correctOptionIndex: 0,
        marks: 2,
      );

      final restored = ExamQuestion.fromJson(source.toJson());

      expect(restored.prompt, 'حل المعادلة');
      expect(restored.content.length, 2);
      expect(restored.content[0].type, ExamContentBlockType.text);
      expect(restored.content[1].type, ExamContentBlockType.equation);
      expect(
        restored.content[1].value,
        r'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
      );
    });

    test('legacy prompt remains visible through effectiveContent', () {
      const question = ExamQuestion(
        id: 'legacy',
        type: ExamQuestionType.essay,
        prompt: 'سؤال قديم',
      );

      expect(question.effectiveContent.length, 1);
      expect(question.effectiveContent.first.value, 'سؤال قديم');
    });
  });

  group('Exam paper template', () {
    test('round trips the A4 template settings', () {
      const template = ExamPaperTemplate(
        schoolName: 'مدرسة الأنوار الأساسية',
        examTitle: 'امتحان شهري للعام الدراسي',
        academicYear: '2026 - 2027',
        instruction: 'أجب عن جميع الأسئلة التالية:',
        showQuestionMarks: false,
        showPageNumber: true,
      );

      final restored = ExamPaperTemplate.fromJson(template.toJson());

      expect(restored.schoolName, 'مدرسة الأنوار الأساسية');
      expect(restored.academicYear, '2026 - 2027');
      expect(restored.instruction, 'أجب عن جميع الأسئلة التالية:');
      expect(restored.showQuestionMarks, isFalse);
      expect(restored.showPageNumber, isTrue);
    });

    test('exam round trip keeps the template', () {
      const exam = Exam(
        id: 'exam1',
        title: 'اختبار رياضيات',
        subject: 'رياضيات',
        className: 'السابع',
        template: ExamPaperTemplate(
          schoolName: 'مدرسة الاختبار',
          academicYear: '2026 - 2027',
        ),
      );

      final restored = Exam.fromJson(exam.toJson());

      expect(restored.template.schoolName, 'مدرسة الاختبار');
      expect(restored.template.academicYear, '2026 - 2027');
    });
  });
}
