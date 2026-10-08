class SchoolPeriod {
  const SchoolPeriod({
    required this.id,
    required this.name,
    required this.startMinutes,
    required this.durationMinutes,
    this.teacherSelectable = true,
  });

  final String id;
  final String name;
  final int startMinutes;
  final int durationMinutes;
  final bool teacherSelectable;

  int get endMinutes => startMinutes + durationMinutes;

  SchoolPeriod copyWith({
    String? id,
    String? name,
    int? startMinutes,
    int? durationMinutes,
    bool? teacherSelectable,
  }) {
    return SchoolPeriod(
      id: id ?? this.id,
      name: name ?? this.name,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      teacherSelectable: teacherSelectable ?? this.teacherSelectable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'teacherSelectable': teacherSelectable,
    };
  }

  factory SchoolPeriod.fromJson(Map<String, dynamic> json) {
    return SchoolPeriod(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startMinutes: int.tryParse(json['startMinutes']?.toString() ?? '') ?? 0,
      durationMinutes:
          int.tryParse(json['durationMinutes']?.toString() ?? '') ?? 35,
      teacherSelectable: json['teacherSelectable'] is bool
          ? json['teacherSelectable'] as bool
          : true,
    );
  }
}
