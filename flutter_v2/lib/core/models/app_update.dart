enum AppUpdateStatus {
  updateAvailable,
  upToDate,
  noPublishedRelease,
  unavailable,
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.tag,
    required this.version,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String tag;
  final String version;
  final String title;
  final String notes;
  final Uri releaseUrl;
  final Uri downloadUrl;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.status,
    required this.message,
    this.update,
  });

  final AppUpdateStatus status;
  final String message;
  final AppUpdateInfo? update;

  bool get hasUpdate =>
      status == AppUpdateStatus.updateAvailable && update != null;
}
