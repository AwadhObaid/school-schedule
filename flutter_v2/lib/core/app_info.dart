abstract final class AppInfo {
  static const appName = 'التوقيت المدرسي';
  static const version = '2.11.6+28';
  static const developerName = 'عوض بن قفله';

  static const githubRepositoryUrl =
      'https://github.com/AwadhObaid/school-schedule';
  static const releasesUrl =
      'https://github.com/AwadhObaid/school-schedule/releases';
  static const latestReleaseApiUrl =
      'https://api.github.com/repos/AwadhObaid/school-schedule/releases/latest';
  static const stableDownloadUrl =
      'https://github.com/AwadhObaid/school-schedule/releases/latest/download/SchoolSchedule.apk';

  // Share the stable direct APK URL so recipients download the app itself,
  // not the repository page.
  static const shareUrl = stableDownloadUrl;

  static const shareText =
      'تطبيق التوقيت المدرسي\n'
      'إعداد وتطوير: عوض بن قفله\n'
      '$shareUrl';
}
