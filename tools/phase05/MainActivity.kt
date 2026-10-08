package com.salaheddine.schedule

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "school_schedule/audio"
        private const val PICK_RINGTONE_REQUEST = 6105
        private const val PREFS = "school_schedule_audio"
        private const val URI_KEY = "ringtone_uri"
        private const val NAME_KEY = "ringtone_name"
        private const val VOLUME_KEY = "bell_volume"
        private const val CHANNEL_KEY = "notification_channel_id"
        private const val CHANNEL_PREFIX = "teacher_class_alerts_"
        private const val MAX_RINGTONE_BYTES = 20L * 1024L * 1024L
    }

    private var previewRingtone: Ringtone? = null
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> configure(call, result)
                "pickRingtone" -> pickRingtone(result)
                "playPreview" -> playPreview(call, result)
                "stopPreview" -> {
                    stopPreview()
                    result.success(null)
                }
                "resetRingtone" -> {
                    resetRingtone()
                    result.success(null)
                }
                "getSettings" -> result.success(readSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun preferences() =
        getSharedPreferences(PREFS, MODE_PRIVATE)

    private fun defaultNotificationUri(): Uri =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

    private fun parseUri(value: String?): Uri {
        if (value.isNullOrBlank()) return defaultNotificationUri()
        return try {
            Uri.parse(value)
        } catch (_: Exception) {
            defaultNotificationUri()
        }
    }

    private fun readSettings(): Map<String, Any> {
        val prefs = preferences()
        return mapOf(
            "uri" to (prefs.getString(URI_KEY, "") ?: ""),
            "name" to (prefs.getString(NAME_KEY, "نغمة النظام") ?: "نغمة النظام"),
            "volume" to prefs.getInt(VOLUME_KEY, 80),
            "channelId" to (prefs.getString(CHANNEL_KEY, "") ?: "")
        )
    }

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val uriValue = call.argument<String>("uri") ?: ""
        val requestedName = call.argument<String>("name")?.trim().orEmpty()
        val name = if (requestedName.isEmpty()) {
            if (uriValue.isEmpty()) "نغمة النظام" else "نغمة من الجهاز"
        } else {
            requestedName
        }
        val volume = (call.argument<Number>("volume")?.toInt() ?: 80)
            .coerceIn(0, 100)

        val prefs = preferences()
        prefs.edit()
            .putString(URI_KEY, uriValue)
            .putString(NAME_KEY, name)
            .putInt(VOLUME_KEY, volume)
            .apply()

        val channelId = configureNotificationChannel(uriValue)
        result.success(mapOf("channelId" to channelId))
    }

    private fun configureNotificationChannel(uriValue: String): String {
        val channelId = CHANNEL_PREFIX + Integer.toHexString(uriValue.hashCode())
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            preferences().edit().putString(CHANNEL_KEY, channelId).apply()
            return channelId
        }

        val manager = getSystemService(NotificationManager::class.java)
            ?: return channelId

        val previousChannelId = preferences().getString(CHANNEL_KEY, null)
        if (!previousChannelId.isNullOrBlank() &&
            previousChannelId != channelId &&
            previousChannelId.startsWith(CHANNEL_PREFIX)
        ) {
            manager.deleteNotificationChannel(previousChannelId)
        }

        val soundUri = parseUri(uriValue)
        if (soundUri.scheme == ContentResolver.SCHEME_CONTENT) {
            try {
                grantUriPermission(
                    "com.android.systemui",
                    soundUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
                // Some vendors use a different SystemUI package. The channel
                // can still be created and the foreground preview remains valid.
            }
        }

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            channelId,
            "تنبيهات الحصص",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "تنبيهات الحصص والجرس"
            enableVibration(true)
            setSound(soundUri, attributes)
        }

        manager.createNotificationChannel(channel)
        preferences().edit().putString(CHANNEL_KEY, channelId).apply()
        return channelId
    }

    private fun pickRingtone(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "A ringtone picker is already open.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "audio/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        pendingPickerResult = result

        try {
            startActivityForResult(intent, PICK_RINGTONE_REQUEST)
        } catch (_: ActivityNotFoundException) {
            intent.action = Intent.ACTION_GET_CONTENT
            try {
                startActivityForResult(intent, PICK_RINGTONE_REQUEST)
            } catch (error: Exception) {
                pendingPickerResult = null
                result.error("picker_unavailable", error.message, null)
            }
        } catch (error: Exception) {
            pendingPickerResult = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android SDK but retained for broad device compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_RINGTONE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingPickerResult
        pendingPickerResult = null

        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val picked = data.data!!
        try {
            val selection = copyRingtoneIntoApp(picked)
            result.success(selection)
        } catch (error: Exception) {
            val code = when (error.message) {
                "file_too_large" -> "file_too_large"
                "file_unreadable" -> "file_unreadable"
                else -> "file_save_failed"
            }
            result.error(code, error.message, null)
        }
    }

    private fun copyRingtoneIntoApp(picked: Uri): Map<String, String> {
        val displayName = queryDisplayName(picked)
        val directory = File(filesDir, "ringtones")
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("file_save_failed")
        }

        val mime = contentResolver.getType(picked)
        val extension = mime
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.takeIf { it.isNotBlank() }

        val suffix = if (extension == null) ".audio" else ".$extension"
        val outputFile = File.createTempFile("bell-", suffix, directory)

        try {
            contentResolver.openInputStream(picked).use { input ->
                if (input == null) throw IllegalStateException("file_unreadable")
                FileOutputStream(outputFile).use { output ->
                    copyWithLimit(input, output)
                }
            }
        } catch (error: Exception) {
            outputFile.delete()
            throw error
        }

        clearRingtoneFiles(except = outputFile)

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            outputFile
        )

        preferences().edit()
            .putString(URI_KEY, uri.toString())
            .putString(NAME_KEY, displayName)
            .apply()

        return mapOf(
            "uri" to uri.toString(),
            "name" to displayName
        )
    }

    private fun copyWithLimit(input: InputStream, output: FileOutputStream) {
        val buffer = ByteArray(8192)
        var total = 0L

        while (true) {
            val count = input.read(buffer)
            if (count == -1) break

            total += count
            if (total > MAX_RINGTONE_BYTES) {
                throw IllegalStateException("file_too_large")
            }
            output.write(buffer, 0, count)
        }

        if (total <= 0L) {
            throw IllegalStateException("file_unreadable")
        }
    }

    private fun queryDisplayName(uri: Uri): String {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && !cursor.isNull(index)) {
                    cursor.getString(index).takeIf { it.isNotBlank() }
                        ?: "نغمة من الجهاز"
                } else {
                    "نغمة من الجهاز"
                }
            } else {
                "نغمة من الجهاز"
            }
        } catch (_: Exception) {
            "نغمة من الجهاز"
        } finally {
            cursor?.close()
        }
    }

    private fun playPreview(call: MethodCall, result: MethodChannel.Result) {
        val uriValue = call.argument<String>("uri")
            ?: preferences().getString(URI_KEY, "")
            ?: ""
        val volume = (call.argument<Number>("volume")?.toInt()
            ?: preferences().getInt(VOLUME_KEY, 80))
            .coerceIn(0, 100) / 100f

        try {
            stopPreview()

            val ringtone = RingtoneManager.getRingtone(this, parseUri(uriValue))
            if (ringtone == null) {
                result.error("ringtone_unavailable", "Ringtone is unavailable.", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone.volume = volume
            }

            previewRingtone = ringtone
            ringtone.play()

            Handler(Looper.getMainLooper()).postDelayed({
                stopPreview()
            }, 3500L)

            result.success(null)
        } catch (error: Exception) {
            result.error("ringtone_unavailable", error.message, null)
        }
    }

    private fun stopPreview() {
        try {
            previewRingtone?.let {
                if (it.isPlaying) it.stop()
            }
        } catch (_: Exception) {
            // Best effort.
        } finally {
            previewRingtone = null
        }
    }

    private fun resetRingtone() {
        stopPreview()
        clearRingtoneFiles(except = null)

        val volume = preferences().getInt(VOLUME_KEY, 80)
        preferences().edit()
            .putString(URI_KEY, "")
            .putString(NAME_KEY, "نغمة النظام")
            .putInt(VOLUME_KEY, volume)
            .apply()
    }

    private fun clearRingtoneFiles(except: File?) {
        val directory = File(filesDir, "ringtones")
        val files = directory.listFiles() ?: return
        files.forEach { file ->
            if (except == null || file.absolutePath != except.absolutePath) {
                file.delete()
            }
        }
    }
}
