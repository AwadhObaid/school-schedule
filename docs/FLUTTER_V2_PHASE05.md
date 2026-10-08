# Flutter V2 — Phase 05: Bell audio, ringtone and volume

## Goal
Port the proven native bell-audio behavior from the legacy Capacitor application into Flutter V2 without adding a third-party ringtone picker dependency.

## Included
- School bell sound master switch.
- Automatic foreground bell when the active school-schedule state changes.
- Device audio file picker using Android ACTION_OPEN_DOCUMENT.
- Selected audio copied into app-private storage so it survives restarts.
- 20 MB maximum custom ringtone size, matching the legacy application.
- Current ringtone name display.
- Restore system notification sound.
- Bell volume 0–100%.
- 3.5 second ringtone preview.
- Selected ringtone reused for Android teacher-notification channels.
- Notification schedules are rebuilt after ringtone changes.
- Bell settings stored locally.
- Platform code isolated behind a MethodChannel service so Flutter tests remain deterministic.

## Android native bridge
Channel: school_schedule/audio

Methods:
- configure
- pickRingtone
- playPreview
- stopPreview
- resetRingtone

The local installer adds the native Android bridge, FileProvider declaration, and file_paths.xml.

## Behavior parity
The legacy application default remains:
- School bell sound: off
- Volume: 80%
- Ringtone: system notification sound

Foreground bell playback only occurs while Flutter is active. Background reminders continue to use the operating-system notification scheduler built in Phase 03.
