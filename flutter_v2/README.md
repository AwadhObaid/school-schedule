# School Schedule — Flutter V2

هذه هي قاعدة إعادة بناء تطبيق **التوقيت المدرسي** باستخدام Flutter مع الحفاظ على النسخة الحالية (Capacitor) دون تعديلها.

## هوية التطبيق
- Android applicationId: `com.salaheddine.schedule`
- App name: `التوقيت المدرسي`
- Flutter package/project name: `schedule`
- Baseline version: `2.0.0+8`

## Phase 01
- Flutter Material 3 foundation.
- Arabic RTL application shell.
- Bottom navigation: الرئيسية / حصصي / الجدول / الإعدادات.
- Initial visual home screen matching the approved concept.
- Core data models for school periods and teacher classes.
- Smoke test.
- Bootstrap PowerShell script that generates the Android platform folder without replacing the current legacy Android app.

## Important
The existing root `android/`, `www/`, Capacitor files and version `1.4.2` remain untouched. Flutter V2 lives under `flutter_v2/` until migration is complete and verified.
