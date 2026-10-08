# Flutter V2 — Phase 03: Teacher class alerts

## Goal
Add personal local notifications that are generated from the teacher's saved weekly classes.

## Included
- Master switch for **My Classes notifications**.
- Pre-class alert options: off, 1, 3, 5, 10 or 15 minutes.
- Class-start notification.
- Class-end notification with the next saved class in the weekly cycle.
- Weekly scheduling tied to the same period source used by the home screen.
- Automatic rescheduling whenever a teacher class is added, edited or removed.
- Android notification permission request.
- Android exact-alarm request when available, with automatic inexact fallback if exact permission is unavailable.
- Re-scheduling after reboot through the Android plugin receivers.
- Test-notification button in Settings.
- Local persistence for notification preferences.

## Android notes
Phase 03 uses flutter_local_notifications 22.3.1, flutter_timezone 5.1.0 and timezone 0.11.1.

The local installer patches the generated Android scaffold to add:
- RECEIVE_BOOT_COMPLETED
- SCHEDULE_EXACT_ALARM
- scheduled notification receivers
- core library desugaring
- a monochrome notification icon

The legacy Capacitor application remains unchanged.
