package com.salaheddine.schedule;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ActivityNotFoundException;
import android.database.Cursor;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;
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
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("audio/*");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            startActivityForResult(call, intent, "handleRingtonePickerResult");
        } catch (ActivityNotFoundException error) {
            intent.setAction(Intent.ACTION_GET_CONTENT);
            try {
                startActivityForResult(call, intent, "handleRingtonePickerResult");
            } catch (Exception fallbackError) {
                call.reject("picker_unavailable", fallbackError);
            }
        } catch (Exception error) {
            call.reject("picker_unavailable", error);
        }
    }

    @ActivityCallback
    private void handleRingtonePickerResult(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
            call.reject("canceled");
            return;
        }
        Uri picked = result.getData().getData();
        if (picked == null) { call.reject("file_unreadable"); return; }
        String uri = picked == null ? "" : picked.toString();
        String name = "نغمة من الجهاز";
        try (Cursor cursor = getContext().getContentResolver().query(picked, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0);
        } catch (Exception ignored) { }
        File copy = null;
        if (picked != null) {
            try {
                File directory = new File(getContext().getFilesDir(), "ringtones");
                if (!directory.exists() && !directory.mkdirs()) throw new java.io.IOException("Cannot create ringtone directory");
                String mime = getContext().getContentResolver().getType(picked);
                String extension = mime == null ? null : MimeTypeMap.getSingleton().getExtensionFromMimeType(mime);
                copy = File.createTempFile("bell-", extension == null ? ".audio" : "." + extension, directory);
                try (InputStream input = getContext().getContentResolver().openInputStream(picked);
                     FileOutputStream output = new FileOutputStream(copy)) {
                    if (input == null) throw new java.io.IOException("Cannot read ringtone");
                    byte[] buffer = new byte[8192];
                    int count;
                    long total = 0;
                    while ((count = input.read(buffer)) != -1) {
                        total += count;
                        if (total > 20L * 1024 * 1024) throw new java.io.IOException("file_too_large");
                        output.write(buffer, 0, count);
                    }
                    if (total == 0) throw new java.io.IOException("file_unreadable");
                }
                uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", copy).toString();
            } catch (Exception error) {
                if (copy != null) copy.delete();
                call.reject("file_too_large".equals(error.getMessage()) ? "file_too_large" : "file_save_failed", error);
                return;
            }
        }
        preferences().edit().putString(URI_KEY, uri).putString(NAME_KEY, name).apply();
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
