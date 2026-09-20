# Flutter V2 — Phase 09: Production readiness and legacy migration

## Goal
Prepare Flutter V2 for a future in-place replacement of the stable Capacitor application without changing the production package or signing configuration yet.

## Legacy baseline verified
- Production package: `com.salaheddine.schedule`
- Stable legacy version: `1.4.2`
- Stable legacy versionCode: `7`
- Legacy state schema: `4`
- Legacy WebView localStorage key: `schoolScheduleState_v2`
- Legacy backup format: `school-schedule-backup`
- Legacy backupVersion: `1`
- Release signing is configured through external environment variables:
  - `RELEASE_KEYSTORE_PATH`
  - `RELEASE_KEYSTORE_PASSWORD`
  - `RELEASE_KEY_ALIAS`
  - `RELEASE_KEY_PASSWORD`

The signing key is not stored in the repository.

## Added in Phase 09

### Legacy backup importer
Flutter V2 can read a JSON backup exported by the old application and convert:
- School schedules.
- Custom schedules.
- Weekday schedule assignments.
- Ramadan mode.
- Settings PIN.
- Bell enabled state.
- Bell volume.
- Notification enabled state.

The importer preserves:
- Flutter V2 teacher classes ("My Classes").
- Flutter V2 appearance preference.

### Ringtone limitation
The old JSON backup only stores a ringtone URI/name and does not embed the ringtone file.
A legacy FileProvider URI is not portable between applications/devices.

If a legacy backup used a custom ringtone:
- the migration reports this explicitly,
- Flutter V2 falls back to the system notification sound,
- the user can select the ringtone again from the device.

### Safe mapping of legacy periods
- Assembly-like names are imported as non-teacher period `assembly`.
- Break/recess-like names are imported as non-teacher period `break`.
- Other periods become `p1`, `p2`, ... in chronological order.
- Overlapping periods and periods beyond midnight are rejected.

### Production preflight
A read-only PowerShell checker is included at:
`tools/phase09/production_preflight.ps1`

It checks:
- ADB connectivity.
- Installed production package metadata.
- Installed Flutter V2 test package metadata.
- APK path for the production package.
- Installed production certificate SHA-256 when Android build-tools/apksigner is available.
- Presence (not values) of expected release-signing environment variables.
- Current local Flutter V2 source version.

No package is installed, removed, cleared or modified by the checker.

## Parity audit

### Complete / migrated
- Multiple schedules and custom schedules.
- Weekday-to-schedule mapping.
- Ramadan mode.
- School bell while Flutter is active.
- Custom ringtone picker and persistence.
- Bell volume.
- Personal teacher-class notifications.
- Teacher-class current/next calculations.
- Backup/restore for Flutter V2.
- Settings PIN.
- Dark/light/system appearance.
- App sharing.
- Developer information.
- Legacy JSON backup migration.

### Remaining before production replacement
1. Global school-period background notifications from the legacy app are not yet equivalent.
   The legacy app schedules start/end notifications for all school periods even when "My Classes" is unused.
2. The home screen is teacher-focused. A global live school-period state equivalent to the legacy main screen should remain available even if the teacher has no personal classes.
3. Final Android package has not yet been switched from the side-by-side test package back to `com.salaheddine.schedule`.
4. Final release APK has not yet been signed and compared against the installed legacy certificate.
5. In-place upgrade over legacy 1.4.2 has not yet been attempted.
6. Final launcher icon/splash/release share URL should be frozen before production.
7. Legacy WebView localStorage is intentionally not read directly because parsing Chromium LevelDB is brittle. Migration uses the legacy application's existing validated JSON export path instead.

## Production rule
Do not uninstall the stable legacy application to test migration. The final production rehearsal must use an Android in-place update signed by the same production certificate.

## Version
2.8.0+17
