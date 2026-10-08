import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/app_info.dart';

void main() {
  test('share text uses the stable direct APK download URL', () {
    expect(AppInfo.version, '2.11.6+28');
    expect(AppInfo.shareUrl, AppInfo.stableDownloadUrl);
    expect(
      AppInfo.shareUrl,
      'https://github.com/AwadhObaid/school-schedule/releases/latest/download/SchoolSchedule.apk',
    );
    expect(AppInfo.shareText, contains(AppInfo.stableDownloadUrl));
    expect(
      AppInfo.shareText,
      isNot(contains('https://github.com/AwadhObaid/school-schedule\n')),
    );
  });
}
