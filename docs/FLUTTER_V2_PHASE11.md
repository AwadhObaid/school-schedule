# Flutter V2 — Phase 11: Splash, app icon and update checker

## Goal
Finish the visible application identity and add a safe GitHub Releases update flow without changing the production Android package yet.

## Included

### Splash screen
- Native Android splash generated with `flutter_native_splash`.
- Flutter splash screen shown while local app initialization completes.
- Minimum visible duration in production builds to avoid a flash.
- Displays the application icon, app name, short description and developer name.
- Test-injected controllers skip the artificial delay so widget tests remain fast.

### Application icon
- Reuses the existing School Schedule visual identity from the legacy application.
- Source asset: `assets/images/app_icon.png`.
- Android launcher icon generated using `flutter_launcher_icons`.
- Adaptive icon background uses the existing navy brand color `#17365D`.

### Update checking
The application checks the repository's latest published GitHub Release:
`https://api.github.com/repos/AwadhObaid/school-schedule/releases/latest`

Behavior:
- Automatic silent check after the main UI opens.
- Manual check from Settings > Updates.
- Network failures never block application startup.
- A repository with no published releases is handled normally.
- Semantic version comparison ignores an optional leading `v`.
- If the newest release contains an APK asset, "Update now" opens that APK URL directly.
- If no APK asset is attached, it opens the release page.
- Update dialog displays the release title and GitHub Release body as "What's new".
- User choices: Update now, Later, Ignore this release.
- Ignored release tags are stored locally and suppressed from automatic checks.
- Manual checks ignore the suppression so the user can still see the release.

### Android internet permission
The Phase 11 installer ensures:
`android.permission.INTERNET`

### Current repository state
At the time Phase 11 was created, the GitHub repository had no published Releases.
Therefore the manual checker should currently report that no releases are published.
The update-available path is covered by automated tests and will activate automatically after the first release is published.

## Packages
- `http` for GitHub API access.
- `url_launcher` for opening the APK/release URL.
- `flutter_native_splash` for native splash generation.
- `flutter_launcher_icons` for Android launcher icon generation.

## Safety
- Production package `com.salaheddine.schedule` is not changed.
- Side-by-side test package remains `com.salaheddine.schedule.flutterv2`.
- Stable legacy application is not uninstalled or modified.

## Version
2.10.0+19
