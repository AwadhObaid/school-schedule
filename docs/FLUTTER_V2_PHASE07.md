# Flutter V2 — Phase 07: Developer info, dark mode and app sharing

## Goal
Add final user-facing identity and convenience features requested after Phase 06.

## Included
- Developer information displayed as: عوض بن قفله.
- About section with app name and version.
- Theme preference with three modes: System, Light and Dark.
- Theme preference persists locally.
- Dark Material 3 theme with adjusted cards, navigation, text, schedule highlights and teacher-class grids.
- Appearance preference is included in Flutter V2 backup files.
- Older Phase 06 backups that do not contain an appearance field restore safely using Light mode to preserve the previous UI.
- Native Android share sheet for sharing the application.
- Sharing text contains the application name, developer name and public project link.

## Share link
Until the final Flutter V2 production release is published, sharing uses:
https://github.com/AwadhObaid/school-schedule

The URL is centralized in AppInfo.shareUrl so it can be replaced later with a stable direct APK release URL without changing the Settings UI.

## Android native bridge
Channel: school_schedule/share

Method:
- shareText

No third-party sharing package is added.

## Version
2.6.0+15
