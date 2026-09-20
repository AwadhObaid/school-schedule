class SchoolPeriod {
  const SchoolPeriod({
    required this.id,
    required this.name,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final int startMinutes;
  final int durationMinutes;

  int get endMinutes => startMinutes + durationMinutes;
}
