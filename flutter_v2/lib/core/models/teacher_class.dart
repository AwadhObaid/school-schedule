class TeacherClass {
  const TeacherClass({
    required this.weekday,
    required this.periodId,
    required this.subject,
    this.classroom,
    this.notes,
    this.enabled = true,
  });

  /// DateTime weekday: Monday = 1 ... Sunday = 7.
  final int weekday;
  final String periodId;
  final String subject;
  final String? classroom;
  final String? notes;
  final bool enabled;

  String get storageKey => '$weekday:$periodId';

  TeacherClass copyWith({
    int? weekday,
    String? periodId,
    String? subject,
    String? classroom,
    String? notes,
    bool? enabled,
  }) {
    return TeacherClass(
      weekday: weekday ?? this.weekday,
      periodId: periodId ?? this.periodId,
      subject: subject ?? this.subject,
      classroom: classroom ?? this.classroom,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'periodId': periodId,
      'subject': subject,
      'classroom': classroom,
      'notes': notes,
      'enabled': enabled,
    };
  }

  factory TeacherClass.fromJson(Map<String, dynamic> json) {
    return TeacherClass(
      weekday: int.tryParse(json['weekday']?.toString() ?? '') ?? DateTime.sunday,
      periodId: json['periodId']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      classroom: _nullableString(json['classroom']),
      notes: _nullableString(json['notes']),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
