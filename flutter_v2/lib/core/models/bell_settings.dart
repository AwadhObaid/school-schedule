class BellSettings {
  const BellSettings({
    this.enabled = false,
    this.ringtoneUri = '',
    this.ringtoneName = 'نغمة النظام',
    this.volume = 80,
  });

  final bool enabled;
  final String ringtoneUri;
  final String ringtoneName;
  final int volume;

  bool get usesSystemRingtone => ringtoneUri.trim().isEmpty;

  BellSettings copyWith({
    bool? enabled,
    String? ringtoneUri,
    String? ringtoneName,
    int? volume,
  }) {
    return BellSettings(
      enabled: enabled ?? this.enabled,
      ringtoneUri: ringtoneUri ?? this.ringtoneUri,
      ringtoneName: ringtoneName ?? this.ringtoneName,
      volume: (volume ?? this.volume).clamp(0, 100).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'ringtoneUri': ringtoneUri,
      'ringtoneName': ringtoneName,
      'volume': volume,
    };
  }

  factory BellSettings.fromJson(Map<String, dynamic> json) {
    final rawVolume = int.tryParse(json['volume']?.toString() ?? '') ?? 80;
    final rawName = json['ringtoneName']?.toString().trim() ?? '';

    return BellSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      ringtoneUri: json['ringtoneUri']?.toString() ?? '',
      ringtoneName: rawName.isEmpty ? 'نغمة النظام' : rawName,
      volume: rawVolume.clamp(0, 100).toInt(),
    );
  }
}
