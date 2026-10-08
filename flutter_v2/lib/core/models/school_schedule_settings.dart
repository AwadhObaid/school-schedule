import 'school_period.dart';

class SchoolScheduleProfile {
  const SchoolScheduleProfile({
    required this.id,
    required this.name,
    required this.periods,
  });

  final String id;
  final String name;
  final List<SchoolPeriod> periods;

  List<SchoolPeriod> get teachingPeriods => List<SchoolPeriod>.unmodifiable(
        periods.where((item) => item.teacherSelectable),
      );

  SchoolScheduleProfile copyWith({
    String? id,
    String? name,
    List<SchoolPeriod>? periods,
  }) {
    return SchoolScheduleProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      periods: periods ?? this.periods,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'periods': periods.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory SchoolScheduleProfile.fromJson(Map<String, dynamic> json) {
    final rawPeriods = json['periods'];
    final periods = rawPeriods is List
        ? rawPeriods
            .whereType<Map>()
            .map((item) => SchoolPeriod.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false)
        : const <SchoolPeriod>[];

    return SchoolScheduleProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      periods: periods,
    );
  }
}

class SchoolScheduleSettings {
  const SchoolScheduleSettings({
    required this.ramadanMode,
    required this.weekdayMap,
    required this.profiles,
  });

  static const offProfileId = 'off';
  static const normalProfileId = 'normal';
  static const ramadanProfileId = 'ramadan';

  final bool ramadanMode;
  final Map<int, String> weekdayMap;
  final Map<String, SchoolScheduleProfile> profiles;

  String effectiveProfileIdForWeekday(int weekday) {
    var id = weekdayMap[weekday] ?? offProfileId;
    if (ramadanMode &&
        id == normalProfileId &&
        profiles.containsKey(ramadanProfileId)) {
      id = ramadanProfileId;
    }
    return id;
  }

  SchoolScheduleProfile? profileForWeekday(int weekday) {
    final id = effectiveProfileIdForWeekday(weekday);
    if (id == offProfileId) return null;
    return profiles[id];
  }

  List<SchoolPeriod> teachingPeriodsForWeekday(int weekday) {
    return profileForWeekday(weekday)?.teachingPeriods ??
        const <SchoolPeriod>[];
  }

  SchoolScheduleSettings copyWith({
    bool? ramadanMode,
    Map<int, String>? weekdayMap,
    Map<String, SchoolScheduleProfile>? profiles,
  }) {
    return SchoolScheduleSettings(
      ramadanMode: ramadanMode ?? this.ramadanMode,
      weekdayMap: weekdayMap ?? this.weekdayMap,
      profiles: profiles ?? this.profiles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ramadanMode': ramadanMode,
      'weekdayMap': {
        for (final entry in weekdayMap.entries) entry.key.toString(): entry.value,
      },
      'profiles': {
        for (final entry in profiles.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  factory SchoolScheduleSettings.fromJson(Map<String, dynamic> json) {
    final rawWeekdayMap = json['weekdayMap'];
    final weekdayMap = <int, String>{};
    if (rawWeekdayMap is Map) {
      for (final entry in rawWeekdayMap.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value?.toString();
        if (key != null && value != null && value.isNotEmpty) {
          weekdayMap[key] = value;
        }
      }
    }

    final rawProfiles = json['profiles'];
    final profiles = <String, SchoolScheduleProfile>{};
    if (rawProfiles is Map) {
      for (final entry in rawProfiles.entries) {
        if (entry.value is! Map) continue;
        final profile = SchoolScheduleProfile.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (profile.id.isNotEmpty) {
          profiles[entry.key.toString()] = profile;
        }
      }
    }

    return SchoolScheduleSettings(
      ramadanMode:
          json['ramadanMode'] is bool ? json['ramadanMode'] as bool : false,
      weekdayMap: weekdayMap,
      profiles: profiles,
    );
  }
}
