# Flutter V2 — Phase 04: School schedule management

## Goal
Move the authoritative school schedule from hard-coded Flutter values into editable local data while preserving the stable legacy behavior.

## Included
- Editable normal school-day period start times and durations.
- Editable Ramadan period start times and durations.
- Ramadan mode switch.
- Per-weekday school day / off-day mapping.
- Assembly and break remain part of the school schedule but are not selectable as teacher classes.
- Teacher assignments keep stable IDs (p1..p6), so schedule time edits automatically flow into My Classes.
- Current/next class calculation now reads the active schedule profile.
- Teacher notifications are automatically rescheduled after any school schedule change.
- Reset-to-default action.
- Local persistence through SharedPreferences.

## Legacy baseline copied into defaults

### Normal
- Assembly 07:30 / 15
- P1 07:45 / 35
- P2 08:25 / 35
- P3 09:05 / 35
- Break 09:40 / 20
- P4 10:05 / 35
- P5 10:45 / 35
- P6 11:25 / 35

### Ramadan
- Assembly 08:00 / 10
- P1 08:10 / 30
- P2 08:40 / 30
- Break 09:10 / 15
- P3 09:25 / 30
- P4 09:55 / 30
- P5 10:25 / 30

Friday and Saturday remain off by default.

## Deferred
Custom third-party schedule profiles are not introduced in this phase. The architecture now supports profiles and can be extended later without changing teacher assignment IDs.
