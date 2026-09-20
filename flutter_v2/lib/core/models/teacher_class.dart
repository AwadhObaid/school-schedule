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
}
