package com.salaheddine.schedule;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.io.File;
import java.io.InputStream;
import java.io.FileOutputStream;
import androidx.core.content.FileProvider;

import androidx.activity.result.ActivityResult;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "ScheduleAudio")
public class ScheduleAudioPlugin extends Plugin {
    private static final String PREFS = "school_schedule_audio";
    private static final String URI_KEY = "ringtone_uri";
    private static final String NAME_KEY = "ringtone_name";
    private static final String VOLUME_KEY = "bell_volume";
    private static final String CHANNEL_ID = "school_schedule";
    private Ringtone previewRingtone;

    private SharedPreferences preferences() {
        return getContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private Uri defaultNotificationUri() {
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
    }

    private Uri parseUri(String value) {
        if (value == null || value.trim().isEmpty()) return defaultNotificationUri();
        try {
            return Uri.parse(value);
        } catch (Exception ignored) {
            return defaultNotificationUri();
        }
    }

    private String ringtoneTitle(Uri uri) {
        try {
            Ringtone ringtone = RingtoneManager.getRingtone(getContext(), uri);
            if (ringtone != null) {
                String title = ringtone.getTitle(getContext());
                if (title != null && !title.trim().isEmpty()) return title;
            }
        } catch (Exception ignored) {
            // Fall back to the generic label below.
        }
        return "نغمة النظام";
    }

    @PluginMethod
    public void getSettings(PluginCall call) {
        JSObject result = new JSObject();
        result.put("uri", preferences().getString(URI_KEY, ""));
        result.put("name", preferences().getString(NAME_KEY, "نغمة النظام"));
        result.put("volume", preferences().getInt(VOLUME_KEY, 80));
        call.resolve(result);
    }

    @PluginMethod
    public void pickRingtone(PluginCall call) {
        Intent intent = new Intent(RingtoneManager.ACTION_RINGTONE_PICKER);
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION);
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "اختيار نغمة جرس الحصة");
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false);
        String existing = preferences().getString(URI_KEY, "");
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, existing.isEmpty() ? defaultNotificationUri() : Uri.parse(existing));
        startActivityForResult(call, intent, "handleRingtonePickerResult");
    }

    @ActivityCallback
    private void handleRingtonePickerResult(PluginCall call, ActivityResult result) {
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
            call.reject("canceled");
            return;
        }
        Uri picked = result.getData().getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI);
        String uri = picked == null ? "" : picked.toString();
        String name = picked == null ? "نغمة النظام" : ringtoneTitle(picked);
        if (picked != null) {
            try {
                File directory = new File(getContext().getFilesDir(), "ringtones");
                if (!directory.exists() && !directory.mkdirs()) throw new java.io.IOException("Cannot create ringtone directory");
                File copy = File.createTempFile("bell-", ".audio", directory);
                try (InputStream input = getContext().getContentResolver().openInputStream(picked);
                     FileOutputStream output = new FileOutputStream(copy)) {
                    if (input == null) throw new java.io.IOException("Cannot read ringtone");
                    byte[] buffer = new byte[8192];
                    int count;
                    while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                }
                uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", copy).toString();
            } catch (Exception error) {
                call.reject("Unable to save ringtone", error);
                return;
            }
        }
        JSObject response = new JSObject();
        response.put("uri", uri);
        response.put("name", name);
        call.resolve(response);
    }

    @PluginMethod
    public void configure(PluginCall call) {
        String uri = call.getString("uri", "");
        String name = call.getString("name", uri.isEmpty() ? "نغمة النظام" : ringtoneTitle(parseUri(uri)));
        int volume = Math.max(0, Math.min(100, call.getInt("volume", 80)));
        SharedPreferences prefs = preferences();
        String previousUri = prefs.getString(URI_KEY, "");
        prefs.edit().putString(URI_KEY, uri).putString(NAME_KEY, name).putInt(VOLUME_KEY, volume).apply();

        String channelId = CHANNEL_ID + "_" + Integer.toHexString(uri.hashCode());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager manager = (NotificationManager) getContext().getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager != null) {
                NotificationChannel channel = new NotificationChannel(
                    channelId,
                    "جرس الحصص",
                    NotificationManager.IMPORTANCE_HIGH
                );
                AudioAttributes attributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
                Uri soundUri = parseUri(uri);
                if (soundUri != null && !ContentResolver.SCHEME_ANDROID_RESOURCE.equals(soundUri.getScheme())) {
                    getContext().grantUriPermission("com.android.systemui", soundUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
                }
                channel.setSound(soundUri, attributes);
                manager.createNotificationChannel(channel);
            }
        }
        JSObject response = new JSObject();
        response.put("channelId", channelId);
        call.resolve(response);
    }

    @PluginMethod
    public void playPreview(PluginCall call) {
        String uriValue = call.getString("uri", preferences().getString(URI_KEY, ""));
        Double requestedVolume = call.getDouble("volume");
        double volumeValue = requestedVolume == null ? preferences().getInt(VOLUME_KEY, 80) : requestedVolume;
        float volume = Math.max(0f, Math.min(1f, (float) volumeValue / 100f));
        try {
            if (previewRingtone != null && previewRingtone.isPlaying()) previewRingtone.stop();
            previewRingtone = RingtoneManager.getRingtone(getContext(), parseUri(uriValue));
            if (previewRingtone == null) {
                call.reject("ringtone_unavailable");
                return;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                previewRingtone.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build());
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) previewRingtone.setVolume(volume);
            previewRingtone.play();
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                if (previewRingtone != null && previewRingtone.isPlaying()) previewRingtone.stop();
            }, 3500);
            call.resolve();
        } catch (Exception error) {
            call.reject("ringtone_unavailable", error);
        }
    }
}
