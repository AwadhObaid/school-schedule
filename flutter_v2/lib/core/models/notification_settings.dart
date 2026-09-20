class NotificationSettings {
  const NotificationSettings({
    this.enabled = false,
    this.preAlertMinutes = 5,
    this.startAlert = true,
    this.endAlert = true,
  });

  final bool enabled;
  final int preAlertMinutes;
  final bool startAlert;
  final bool endAlert;

  NotificationSettings copyWith({
    bool? enabled,
    int? preAlertMinutes,
    bool? startAlert,
    bool? endAlert,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      preAlertMinutes: preAlertMinutes ?? this.preAlertMinutes,
      startAlert: startAlert ?? this.startAlert,
      endAlert: endAlert ?? this.endAlert,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'preAlertMinutes': preAlertMinutes,
      'startAlert': startAlert,
      'endAlert': endAlert,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final preAlert = int.tryParse(json['preAlertMinutes']?.toString() ?? '');
    return NotificationSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      preAlertMinutes: _allowedPreAlert(preAlert) ? preAlert! : 5,
      startAlert:
          json['startAlert'] is bool ? json['startAlert'] as bool : true,
      endAlert: json['endAlert'] is bool ? json['endAlert'] as bool : true,
    );
  }

  static bool _allowedPreAlert(int? value) {
    return const <int>{0, 1, 3, 5, 10, 15}.contains(value);
  }
}
