abstract final class ArabicFormat {
  static const _days = <int, String>{
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
  };

  static const _months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static String dayName(int weekday) => _days[weekday] ?? '';

  static String date(DateTime value) {
    return '${dayName(value.weekday)} ${value.day} ${_months[value.month - 1]}';
  }

  static String clock(DateTime value) {
    final suffix = value.hour < 12 ? 'ص' : 'م';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  static String minutesClock(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final suffix = hour24 < 12 ? 'ص' : 'م';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  static String countdown(Duration duration) {
    var totalSeconds = duration.inSeconds;
    if (totalSeconds < 0) totalSeconds = 0;

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String relative(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return 'الآن';
    if (minutes < 60) return 'بعد $minutes دقيقة';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return 'بعد $hours ساعة';
    return 'بعد $hours ساعة و $rest دقيقة';
  }
}
