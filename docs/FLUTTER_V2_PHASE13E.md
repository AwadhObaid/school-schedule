# Flutter V2 Phase 13E — Release Resource Retention

## Evidence

Production build 2.11.2+24 had notification permissions, exact-alarm permission and scheduled notification receivers in place, but diagnostics of the installed APK showed:

- ic_stat_schedule present: False
- ic_stat_school present: False

The Flutter notification scheduler references ic_stat_schedule by resource name at runtime.

## Root cause

Android release resource shrinking can remove drawable resources that are only referenced dynamically by name. flutter_local_notifications documents this release-build failure mode and recommends a resource keep file.

## Fix

- Add res/raw/keep.xml with:
  tools:keep="@drawable/ic_stat_schedule"
- Reinstall the vector drawable into res/drawable/ic_stat_schedule.xml.
- Verify ic_stat_schedule exists in the built unsigned release APK before signing.
- Verify it again in the signed APK before installation.
- Install with adb install -r only.
- Pull the installed base APK and verify the resource a third time after installation.

## Version

2.11.3+25
