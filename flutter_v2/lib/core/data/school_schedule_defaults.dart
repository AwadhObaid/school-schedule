import '../models/school_period.dart';

abstract final class SchoolScheduleDefaults {
  static const normalTeachingPeriods = <SchoolPeriod>[
    SchoolPeriod(
      id: 'p1',
      name: 'الحصة الأولى',
      startMinutes: 7 * 60 + 45,
      durationMinutes: 35,
    ),
    SchoolPeriod(
      id: 'p2',
      name: 'الحصة الثانية',
      startMinutes: 8 * 60 + 25,
      durationMinutes: 35,
    ),
    SchoolPeriod(
      id: 'p3',
      name: 'الحصة الثالثة',
      startMinutes: 9 * 60 + 5,
      durationMinutes: 35,
    ),
    SchoolPeriod(
      id: 'p4',
      name: 'الحصة الرابعة',
      startMinutes: 10 * 60 + 5,
      durationMinutes: 35,
    ),
    SchoolPeriod(
      id: 'p5',
      name: 'الحصة الخامسة',
      startMinutes: 10 * 60 + 45,
      durationMinutes: 35,
    ),
    SchoolPeriod(
      id: 'p6',
      name: 'الحصة السادسة',
      startMinutes: 11 * 60 + 25,
      durationMinutes: 35,
    ),
  ];

  static SchoolPeriod? byId(String id) {
    for (final period in normalTeachingPeriods) {
      if (period.id == id) return period;
    }
    return null;
  }
}
