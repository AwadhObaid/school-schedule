abstract final class AppInfo {
  static const appName = 'التوقيت المدرسي';
  static const version = '2.10.0+19';
  static const developerName = 'عوض بن قفله';

  static const githubRepositoryUrl =
      'https://github.com/AwadhObaid/school-schedule';
  static const releasesUrl =
      'https://github.com/AwadhObaid/school-schedule/releases';
  static const latestReleaseApiUrl =
      'https://api.github.com/repos/AwadhObaid/school-schedule/releases/latest';
  static const stableDownloadUrl =
      'https://github.com/AwadhObaid/school-schedule/releases/latest/download/SchoolSchedule.apk';

  // Until the first production Flutter release exists, sharing remains on
  // the repository page. Then it can switch to stableDownloadUrl.
  static const shareUrl = githubRepositoryUrl;

  static const shareText =
      'تطبيق التوقيت المدرسي\n'
      'إعداد وتطوير: عوض بن قفله\n'
      '$shareUrl';
}
