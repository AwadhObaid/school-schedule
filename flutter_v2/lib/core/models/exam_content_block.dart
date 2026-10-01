enum ExamContentBlockType {
  text,
  equation,
}

class ExamContentBlock {
  const ExamContentBlock.text(this.value)
      : type = ExamContentBlockType.text;

  const ExamContentBlock.equation(this.value)
      : type = ExamContentBlockType.equation;

  final ExamContentBlockType type;

  /// Plain text or TeX depending on [type].
  final String value;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
    };
  }

  factory ExamContentBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final value = json['value']?.toString() ?? '';

    if (type == ExamContentBlockType.equation.name) {
      return ExamContentBlock.equation(value);
    }

    return ExamContentBlock.text(value);
  }
}
