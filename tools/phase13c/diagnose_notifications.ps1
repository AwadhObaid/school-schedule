param(
    [string]$Package = 'com.salaheddine.schedule'
)

$ErrorActionPreference = 'Continue'

Write-Host '=== SCHOOL SCHEDULE NOTIFICATION DIAGNOSTICS ===' -ForegroundColor Cyan
Write-Host "Package: $Package"
Write-Host ''

Write-Host '--- Android version ---'
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk

Write-Host ''
Write-Host '--- POST_NOTIFICATIONS permission ---'
adb shell pm check-permission $Package android.permission.POST_NOTIFICATIONS

Write-Host ''
Write-Host '--- Notification app-op ---'
adb shell cmd appops get $Package POST_NOTIFICATION

Write-Host ''
Write-Host '--- Exact alarm permission declaration/state ---'
adb shell dumpsys package $Package | Select-String 'SCHEDULE_EXACT_ALARM|POST_NOTIFICATIONS|RECEIVE_BOOT_COMPLETED'

Write-Host ''
Write-Host '--- Scheduled notification receivers ---'
adb shell dumpsys package $Package | Select-String 'ScheduledNotificationReceiver|ScheduledNotificationBootReceiver'

Write-Host ''
Write-Host '--- Notification package/channels ---'
adb shell dumpsys notification --noredact | Select-String -Pattern $Package -Context 2,12

Write-Host ''
Write-Host '=== END DIAGNOSTICS ===' -ForegroundColor Cyan