# Flutter V2 Phase 13C — Notification Reliability Fix

## Trigger

After the successful in-place upgrade from legacy 1.4.2 to Flutter 2.11.0+22:
- scheduled school bell did not fire;
- school schedule test notification did not appear;
- teacher-class test notification did not appear.

## Root causes addressed

1. A legacy migration or backup restore can mark notification/bell settings as enabled before Android notification permission has been reconciled for the Flutter implementation.
2. Test actions previously did not request/recheck permission and failures were only written to debug logs.
3. Scheduled notifications require host Android manifest configuration that flutter_local_notifications 22.3.1 does not inject automatically:
   - RECEIVE_BOOT_COMPLETED
   - SCHEDULE_EXACT_ALARM
   - ScheduledNotificationReceiver
   - ScheduledNotificationBootReceiver

## Fix

- Test buttons now actively reconcile Android notification/exact-alarm permissions.
- Test buttons remain available while notification toggles are off, so they can be used for diagnostics and permission recovery.
- Successful tests re-sync pending school/teacher schedules.
- Test methods report success/failure to AppController instead of silently swallowing failures.
- Backup restore and legacy migration reconcile Android permissions before scheduling restored notification settings.
- Android manifest patcher adds required permissions and scheduled notification receivers.
- Production package remains com.salaheddine.schedule.
- No uninstall and no adb clear are used.

## Version

2.11.1+23