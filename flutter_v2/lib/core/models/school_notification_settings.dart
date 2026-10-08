class SchoolNotificationSettings {
  const SchoolNotificationSettings({
    this.enabled = false,
  });

  final bool enabled;

  SchoolNotificationSettings copyWith({
    bool? enabled,
  }) {
    return SchoolNotificationSettings(
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
    };
  }

  factory SchoolNotificationSettings.fromJson(Map<String, dynamic> json) {
    return SchoolNotificationSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
    );
  }
}
