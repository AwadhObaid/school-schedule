enum AppAppearance {
  system,
  light,
  dark;

  String get storageValue => name;

  static AppAppearance fromStorage(String? value) {
    return AppAppearance.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AppAppearance.system,
    );
  }
}
