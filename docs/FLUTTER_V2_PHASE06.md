# Flutter V2 — Phase 06: Backup, restore and Settings PIN

## Goal
Complete the remaining protection and portability features from the stable legacy application while extending backup coverage to Flutter V2 teacher data.

## Included
- Settings are protected by a numeric PIN every time the Settings tab is opened.
- Default PIN: 0000.
- PIN can be changed to 4–12 digits.
- Backup export as a JSON file through the Android share/save sheet.
- Restore through the Android document picker.
- Validation occurs before any current data is replaced.
- Confirmation dialog shows backup date, teacher-class count and whether a custom ringtone is embedded.
- Automatic reconfiguration of bell sound and teacher notifications after restore.
- Backup schema has an explicit format and version for future migrations.
- Import files are limited to 32 MiB.

## Backup contents
- School timetable and Ramadan mode.
- Weekday/off-day mapping.
- Teacher weekly classes.
- Personal notification settings.
- Bell enabled state and volume.
- Settings PIN.
- Custom ringtone file itself, encoded inside the backup when one is selected.

## Ringtone portability
A FileProvider URI is device-specific and cannot be copied to another device. Phase 06 therefore exports the private ringtone file itself (maximum 20 MiB), then recreates a new private FileProvider URI during restore.

## Android native bridge
Backup channel: school_schedule/backup

Methods:
- shareBackup
- pickBackup

Audio channel additions:
- exportRingtone
- restoreRingtone

The legacy Capacitor application remains unchanged.
