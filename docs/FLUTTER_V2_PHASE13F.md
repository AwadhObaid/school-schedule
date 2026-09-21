# Flutter V2 Phase 13F — Timezone Correctness

## Evidence from the production device

The phone clock and AlarmManager dump were around 17:00 in Asia/Kuwait, while the first newly scheduled School Schedule alarm for the intended 17:02 wall-clock time was registered at 20:02. The exact +3 hour shift proves the scheduled wall-clock value was being interpreted in UTC.

The current notification scheduler used timezone/data/latest.dart and silently fell back to tz.UTC when FlutterTimezone returned an identifier that the default timezone dataset could not resolve.

Asia/Kuwait is an IANA link to Asia/Riyadh. The timezone package default database intentionally omits some links, while latest_all contains all timezone data and links.

## Fix

- Switch from timezone/data/latest.dart to timezone/data/latest_all.dart.
- Resolve the device IANA identifier from flutter_timezone.
- Validate that the resolved TZ offset equals DateTime.now().timeZoneOffset.
- Remove the silent UTC fallback completely.
- If timezone initialization fails, do not create silently wrong scheduled notifications.
- Keep exact AlarmManager scheduling and the Phase 13E notification resource-retention fix unchanged.

## Version

2.11.4+26
