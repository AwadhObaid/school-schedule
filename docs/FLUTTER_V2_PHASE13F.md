# Flutter V2 Phase 13F — Global Dynamic Timezone Correctness

## Goal

School Schedule must work in any supported IANA timezone and must not be restricted to Kuwait, Riyadh, or a fixed UTC offset.

## Runtime behavior

- Uses timezone/data/latest_all.dart so IANA zones and links are available globally.
- Reads the current device timezone with flutter_timezone.
- Validates the timezone database offset against the Android/Dart system offset.
- Never silently falls back to UTC.
- Refreshes timezone before notification scheduling.
- Detects timezone changes whenever the app returns to the foreground.
- Rebuilds personal and general school schedules when the timezone changed.

## Android terminated-app behavior

A native BroadcastReceiver listens for:

- android.intent.action.TIMEZONE_CHANGED
- android.intent.action.TIME_SET

When the app is not running and Android changes timezone:
- reads cached School Schedule notification records;
- preserves each notification's weekday and local wall-clock time;
- changes the cached timezone to ZoneId.systemDefault();
- calculates the next weekly occurrence in the new zone;
- reschedules AlarmManager entries using flutter_local_notifications.

This covers travel between regions without requiring the user to reopen the app first.

## DST

Future alarms are based on named IANA zones rather than fixed offsets, so zones with daylight-saving rules such as Europe/London, America/New_York, Australia/Sydney and others use the date-specific offset from the timezone database.

## Safety

- No hard-coded country timezone.
- No UTC fallback.
- No uninstall.
- No data clear.
- Existing notification ID ranges remain unchanged.

## Version

2.11.4+26
