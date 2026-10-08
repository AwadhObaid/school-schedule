# Flutter V2 Phase 12.1 — Reliable Background Bell

## Problem

The bell ringtone and native Android audio bridge were healthy, but the automatic school bell depended on a one-second Flutter timer in HomeScreen. Android can suspend that timer while the app is backgrounded or the screen is locked, causing the scheduled transition to be missed.

A manual school-notification test confirmed that Android notifications and the selected bell sound work correctly.

## Fix

- Android scheduled school alerts are now the authoritative transport for the automatic bell.
- Enabling "School bell sound" requests notification/exact-alarm permission and schedules the school timetable even when the separate general-school-alert switch is off.
- The selected bell notification channel is used while the bell is enabled.
- If general school alerts are enabled too, the same school schedule is reused; a second bell schedule is not created.
- Disabling the bell cancels the school schedule only when general school alerts are also disabled.
- If notification permission is denied, the bell toggle is not left falsely enabled.
- HomeScreen's one-second timer now updates countdown/UI only and no longer plays the bell, preventing a foreground double-ring.
- Schedule/Ramadan/custom-profile changes continue to rebuild the Android schedule.

## Expected behavior

With the bell enabled, Android can ring at timetable transitions when:
- the app is in the background;
- the screen is locked;
- the Home tab is not visible;
- there is no internet connection.

Exact timing still depends on Android exact-alarm permission. If exact alarms are unavailable, Android falls back to inexact scheduling and the UI reports that timing may be delayed.

## Version

2.10.1+20
