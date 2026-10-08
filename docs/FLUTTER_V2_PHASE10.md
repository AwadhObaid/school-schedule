# Flutter V2 — Phase 10: Global school state and background schedule notifications

## Goal
Close the largest remaining functional gap with the legacy application: the school timetable must remain useful even when the user has not configured any personal teacher classes.

## Included

### Live global school state
The Home screen now always shows the state of the active school timetable:
- Off day.
- Before school starts.
- Active period.
- Gap between periods.
- School day ended.

For an active period, the card shows:
- Active schedule/profile name.
- Current period name.
- Start/end time.
- Live countdown.
- Progress through the current period.
- Next period when available.

This is independent from "My Classes". Personal teacher-class cards remain below it.

### Background notifications for all school periods
A second notification system is added for the school timetable itself.

It follows the same legacy scheduling behavior:
- A start notification is scheduled for every school period.
- An end notification is scheduled when there is a real gap before the next period.
- No redundant end notification is scheduled when one period ends exactly when the next starts; the next period start notification represents that transition.
- The final period schedules an "school day ended" notification.
- Weekly rules repeat using the device clock.
- Friday/Saturday or any configured Off day has no scheduled school-period notifications.
- Ramadan and custom weekday profiles are respected.
- Notification rules are rebuilt after timetable edits, Ramadan changes, weekday-profile changes, ringtone changes and backup restore.

General school notifications use notification IDs 900000–909999.
Teacher personal notifications continue to use 300000–399999, so the two systems can be managed independently.

### Settings separation
Two independent controls now exist:
1. **School timetable notifications** — general school periods, available even with no personal classes.
2. **My Classes notifications** — personal teacher assignments, including pre-alert/start/end options.

### Legacy migration correction
The old application field `notificationsEnabled` represented general school-period notifications.
Phase 10 maps it to the new general school notification setting.

Existing Flutter V2 personal notification preferences are preserved when importing a legacy backup.

### Backup
Flutter V2 backup files now include the general school notification setting.
Older backups without this field remain valid and default to disabled.

## Legacy behavior reference
The old Capacitor application scheduled weekly Android notifications for every period:
- Start: "بدأت الآن: <period>"
- End during a gap: "انتهت <period>"
- Final end: "انتهى الدوام المدرسي"

Phase 10 reproduces this behavior using `flutter_local_notifications`.

## Version
2.9.0+18
