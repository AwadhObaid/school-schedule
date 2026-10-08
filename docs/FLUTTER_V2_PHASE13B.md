Flutter V2 Phase 13B - Production Signing and In-place Upgrade Rehearsal

Goal
Prepare and verify a production-signed Flutter APK for the original Android package, then rehearse an in-place upgrade over legacy 1.4.2 without uninstalling or clearing data.

Verified legacy baseline
- Package: com.salaheddine.schedule
- Version: 1.4.2
- VersionCode: 7
- Certificate SHA-256: 3845c92da5d39caa76006cfdda25fa2331bfd3542f20d5527cf9e3945524a576

Recovered production key
- Alias: school-schedule-key
- Entry type: PrivateKeyEntry
- Store type: PKCS12
- Certificate matches the installed legacy application.

Phase 13B version
- Flutter version: 2.11.0+22
- Production package: com.salaheddine.schedule

Safety plan
Stage A prepares a signed production APK only. It verifies the connected legacy installation, temporarily switches the local Flutter applicationId to production, builds, signs, verifies package/version/certificate, restores the local Android build file, and does not install anything.

Stage B is performed only after exporting and validating a legacy JSON backup. It archives the backup and installed legacy APK, verifies both signatures again, then uses adb install -r. It never calls uninstall or adb clear.

Important migration rule
The legacy WebView localStorage is not treated as Flutter state. Export the old application's JSON backup before the in-place update. After Flutter starts, import it from Settings > الحماية والنسخ الاحتياطي > استيراد من التطبيق القديم.

Publication rule
Do not publish the first GitHub Release until the in-place rehearsal, data migration, background bell, icon, splash and update checker are verified on the production package.
