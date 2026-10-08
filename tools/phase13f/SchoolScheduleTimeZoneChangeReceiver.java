package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

public final class SchoolScheduleTimeZoneChangeReceiver extends BroadcastReceiver {
    private static final String TAG = "SchoolScheduleTZ";
    private static final String PREFS = "scheduled_notifications";
    private static final String PREFS_KEY = "scheduled_notifications";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            return;
        }

        final String action = intent.getAction();
        if (!Intent.ACTION_TIMEZONE_CHANGED.equals(action)
                && !Intent.ACTION_TIME_CHANGED.equals(action)) {
            return;
        }

        try {
            final SharedPreferences preferences =
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            final String raw = preferences.getString(PREFS_KEY, null);
            if (raw == null || raw.trim().isEmpty()) {
                Log.i(TAG, "No scheduled notifications to refresh.");
                return;
            }

            final JSONArray notifications = new JSONArray(raw);
            final ZoneId newZone = ZoneId.systemDefault();
            final ZonedDateTime now = ZonedDateTime.now(newZone);
            boolean updated = false;

            for (int index = 0; index < notifications.length(); index++) {
                final JSONObject item = notifications.optJSONObject(index);
                if (item == null) {
                    continue;
                }

                final int id = item.optInt("id", -1);
                if (!isSchoolScheduleNotification(id)) {
                    continue;
                }

                final String scheduledText = item.optString("scheduledDateTime", "");
                if (scheduledText.isEmpty()) {
                    continue;
                }

                final LocalDateTime previousLocal = LocalDateTime.parse(scheduledText);
                final LocalDateTime nextLocal = nextWeeklyOccurrence(
                        previousLocal.getDayOfWeek(),
                        previousLocal.toLocalTime(),
                        now);

                item.put("timeZoneName", newZone.getId());
                item.put(
                        "scheduledDateTime",
                        nextLocal.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
                updated = true;
            }

            if (!updated) {
                Log.i(TAG, "No School Schedule alarms needed timezone refresh.");
                return;
            }

            preferences.edit()
                    .putString(PREFS_KEY, notifications.toString())
                    .commit();

            FlutterLocalNotificationsPlugin.rescheduleNotifications(context);

            Log.i(
                    TAG,
                    "Rescheduled School Schedule alarms for timezone "
                            + newZone.getId()
                            + " after "
                            + action);
        } catch (Throwable error) {
            Log.e(TAG, "Failed to reschedule alarms after timezone/time change.", error);
        }
    }

    private static boolean isSchoolScheduleNotification(int id) {
        return (id >= 300000 && id < 400000)
                || (id >= 900000 && id < 910000);
    }

    private static LocalDateTime nextWeeklyOccurrence(
            DayOfWeek weekday,
            LocalTime time,
            ZonedDateTime now) {
        LocalDate date = now.toLocalDate();
        int offset = weekday.getValue() - date.getDayOfWeek().getValue();
        if (offset < 0) {
            offset += 7;
        }

        LocalDateTime candidate = LocalDateTime.of(date.plusDays(offset), time);
        if (!candidate.atZone(now.getZone()).toInstant().isAfter(now.toInstant())) {
            candidate = candidate.plusWeeks(1);
        }
        return candidate;
    }
}
