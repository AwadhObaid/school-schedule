import '../models/school_period.dart';
import '../models/school_schedule_settings.dart';

abstract final class SchoolScheduleDefaults {
  static const normalProfile = SchoolScheduleProfile(
    id: SchoolScheduleSettings.normalProfileId,
    name: 'الدوام العادي',
    periods: <SchoolPeriod>[
      SchoolPeriod(
        id: 'assembly',
        name: 'الطابور',
        startMinutes: 7 * 60 + 30,
        durationMinutes: 15,
        teacherSelectable: false,
      ),
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
        id: 'break',
        name: 'الفسحة',
        startMinutes: 9 * 60 + 40,
        durationMinutes: 20,
        teacherSelectable: false,
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
    ],
  );

  static const ramadanProfile = SchoolScheduleProfile(
    id: SchoolScheduleSettings.ramadanProfileId,
    name: 'دوام رمضان',
    periods: <SchoolPeriod>[
      SchoolPeriod(
        id: 'assembly',
        name: 'الطابور',
        startMinutes: 8 * 60,
        durationMinutes: 10,
        teacherSelectable: false,
      ),
      SchoolPeriod(
        id: 'p1',
        name: 'الحصة الأولى',
        startMinutes: 8 * 60 + 10,
        durationMinutes: 30,
      ),
      SchoolPeriod(
        id: 'p2',
        name: 'الحصة الثانية',
        startMinutes: 8 * 60 + 40,
        durationMinutes: 30,
      ),
      SchoolPeriod(
        id: 'break',
        name: 'الفسحة',
        startMinutes: 9 * 60 + 10,
        durationMinutes: 15,
        teacherSelectable: false,
      ),
      SchoolPeriod(
        id: 'p3',
        name: 'الحصة الثالثة',
        startMinutes: 9 * 60 + 25,
        durationMinutes: 30,
      ),
      SchoolPeriod(
        id: 'p4',
        name: 'الحصة الرابعة',
        startMinutes: 9 * 60 + 55,
        durationMinutes: 30,
      ),
      SchoolPeriod(
        id: 'p5',
        name: 'الحصة الخامسة',
        startMinutes: 10 * 60 + 25,
        durationMinutes: 30,
      ),
    ],
  );

  static const settings = SchoolScheduleSettings(
    ramadanMode: false,
    weekdayMap: <int, String>{
      DateTime.sunday: SchoolScheduleSettings.normalProfileId,
      DateTime.monday: SchoolScheduleSettings.normalProfileId,
      DateTime.tuesday: SchoolScheduleSettings.normalProfileId,
      DateTime.wednesday: SchoolScheduleSettings.normalProfileId,
      DateTime.thursday: SchoolScheduleSettings.normalProfileId,
      DateTime.friday: SchoolScheduleSettings.offProfileId,
      DateTime.saturday: SchoolScheduleSettings.offProfileId,
    },
    profiles: <String, SchoolScheduleProfile>{
      SchoolScheduleSettings.normalProfileId: normalProfile,
      SchoolScheduleSettings.ramadanProfileId: ramadanProfile,
    },
  );

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
}
