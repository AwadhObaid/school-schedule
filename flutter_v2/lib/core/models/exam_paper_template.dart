class ExamPaperTemplate {
  const ExamPaperTemplate({
    this.id = 'standard-a4',
    this.ministry = 'وزارة التربية والتعليم',
    this.educationOffice = 'مكتب التربية',
    this.educationAdministration = 'إدارة التربية والتعليم',
    this.schoolName = 'اسم المدرسة',
    this.examTitle = 'اختبار شهري للعام الدراسي',
    this.academicYear = '',
    this.subjectLabel = 'المادة',
    this.gradeLabel = 'الصف',
    this.dateLabel = 'التاريخ',
    this.durationLabel = 'الزمن',
    this.instruction = 'أجب عن جميع الأسئلة التالية:',
    this.footerRight = '',
    this.footerLeft = 'مع تمنياتنا لكم بالتوفيق والنجاح',
    this.showQuestionMarks = true,
    this.showPageNumber = true,
  });

  final String id;
  final String ministry;
  final String educationOffice;
  final String educationAdministration;
  final String schoolName;
  final String examTitle;
  final String academicYear;
  final String subjectLabel;
  final String gradeLabel;
  final String dateLabel;
  final String durationLabel;
  final String instruction;
  final String footerRight;
  final String footerLeft;
  final bool showQuestionMarks;
  final bool showPageNumber;

  ExamPaperTemplate copyWith({
    String? ministry,
    String? educationOffice,
    String? educationAdministration,
    String? schoolName,
    String? examTitle,
    String? academicYear,
    String? subjectLabel,
    String? gradeLabel,
    String? dateLabel,
    String? durationLabel,
    String? instruction,
    String? footerRight,
    String? footerLeft,
    bool? showQuestionMarks,
    bool? showPageNumber,
  }) {
    return ExamPaperTemplate(
      id: id,
      ministry: ministry ?? this.ministry,
      educationOffice: educationOffice ?? this.educationOffice,
      educationAdministration:
          educationAdministration ?? this.educationAdministration,
      schoolName: schoolName ?? this.schoolName,
      examTitle: examTitle ?? this.examTitle,
      academicYear: academicYear ?? this.academicYear,
      subjectLabel: subjectLabel ?? this.subjectLabel,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      dateLabel: dateLabel ?? this.dateLabel,
      durationLabel: durationLabel ?? this.durationLabel,
      instruction: instruction ?? this.instruction,
      footerRight: footerRight ?? this.footerRight,
      footerLeft: footerLeft ?? this.footerLeft,
      showQuestionMarks: showQuestionMarks ?? this.showQuestionMarks,
      showPageNumber: showPageNumber ?? this.showPageNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ministry': ministry,
      'educationOffice': educationOffice,
      'educationAdministration': educationAdministration,
      'schoolName': schoolName,
      'examTitle': examTitle,
      'academicYear': academicYear,
      'subjectLabel': subjectLabel,
      'gradeLabel': gradeLabel,
      'dateLabel': dateLabel,
      'durationLabel': durationLabel,
      'instruction': instruction,
      'footerRight': footerRight,
      'footerLeft': footerLeft,
      'showQuestionMarks': showQuestionMarks,
      'showPageNumber': showPageNumber,
    };
  }

  factory ExamPaperTemplate.fromJson(Map<String, dynamic> json) {
    bool readBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    return ExamPaperTemplate(
      id: json['id']?.toString() ?? 'standard-a4',
      ministry: json['ministry']?.toString() ?? 'وزارة التربية والتعليم',
      educationOffice: json['educationOffice']?.toString() ?? 'مكتب التربية',
      educationAdministration:
          json['educationAdministration']?.toString() ??
          'إدارة التربية والتعليم',
      schoolName: json['schoolName']?.toString() ?? 'اسم المدرسة',
      examTitle:
          json['examTitle']?.toString() ?? 'اختبار شهري للعام الدراسي',
      academicYear: json['academicYear']?.toString() ?? '',
      subjectLabel: json['subjectLabel']?.toString() ?? 'المادة',
      gradeLabel: json['gradeLabel']?.toString() ?? 'الصف',
      dateLabel: json['dateLabel']?.toString() ?? 'التاريخ',
      durationLabel: json['durationLabel']?.toString() ?? 'الزمن',
      instruction:
          json['instruction']?.toString() ??
          'أجب عن جميع الأسئلة التالية:',
      footerRight: json['footerRight']?.toString() ?? '',
      footerLeft:
          json['footerLeft']?.toString() ??
          'مع تمنياتنا لكم بالتوفيق والنجاح',
      showQuestionMarks:
          readBool('showQuestionMarks', true),
      showPageNumber: readBool('showPageNumber', true),
    );
  }
}
