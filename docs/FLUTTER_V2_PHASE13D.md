# Flutter V2 Phase 13D — Notification Icon Hotfix

## Trigger
On production package 2.11.1+23, both test notification buttons passed permission checks but failed when Android tried to create the notification.

## Root cause
The Flutter notification scheduler referenced Android drawable resource:
`ic_stat_school`

The actual notification drawable present in the Android project is:
`ic_stat_schedule`

flutter_local_notifications rejects notification creation when the configured small icon resource does not exist.

## Fix
- Replace all Flutter notification icon references with `ic_stat_schedule`.
- Ship the vector drawable with the Phase 13D installer and copy it into the local Flutter Android project before building.
- Verify the resource exists before signing/installing.
- Preserve production package, signing certificate and application data.

## Version
2.11.2+24
