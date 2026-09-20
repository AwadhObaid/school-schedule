import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/bell_settings.dart';

class BellRingtoneSelection {
  const BellRingtoneSelection({
    required this.uri,
    required this.name,
  });

  final String uri;
  final String name;
}

class BellRingtoneBackup {
  const BellRingtoneBackup({
    required this.name,
    required this.base64,
  });

  final String name;
  final String base64;
}

abstract class BellAudioService {
  Future<String?> configure(BellSettings settings);

  Future<BellRingtoneSelection?> pickRingtone();

  Future<void> playPreview(BellSettings settings);

  Future<void> resetRingtone();

  Future<void> stopPreview();

  Future<BellRingtoneBackup?> exportRingtone();

  Future<BellRingtoneSelection?> restoreRingtone({
    required String name,
    required String base64,
  });
}

class MethodChannelBellAudioService implements BellAudioService {
  MethodChannelBellAudioService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('school_schedule/audio');

  final MethodChannel _channel;

  @override
  Future<String?> configure(BellSettings settings) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'configure',
        <String, dynamic>{
          'uri': settings.ringtoneUri,
          'name': settings.ringtoneName,
          'volume': settings.volume,
        },
      );
      return result?['channelId']?.toString();
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Bell audio configure failed: $error');
      return null;
    }
  }

  @override
  Future<BellRingtoneSelection?> pickRingtone() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickRingtone',
      );
      if (result == null) return null;

      final uri = result['uri']?.toString() ?? '';
      final name = result['name']?.toString().trim() ?? '';
      if (uri.isEmpty) return null;

      return BellRingtoneSelection(
        uri: uri,
        name: name.isEmpty ? 'نغمة من الجهاز' : name,
      );
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Bell ringtone picker failed: $error');
      return null;
    }
  }

  @override
  Future<void> playPreview(BellSettings settings) async {
    try {
      await _channel.invokeMethod<void>(
        'playPreview',
        <String, dynamic>{
          'uri': settings.ringtoneUri,
          'volume': settings.volume,
        },
      );
    } on MissingPluginException {
      // Platform bridge is installed by the Android installer.
    } catch (error) {
      debugPrint('Bell preview failed: $error');
    }
  }

  @override
  Future<void> resetRingtone() async {
    try {
      await _channel.invokeMethod<void>('resetRingtone');
    } on MissingPluginException {
      // Safe no-op outside Android.
    } catch (error) {
      debugPrint('Bell ringtone reset failed: $error');
    }
  }

  @override
  Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } on MissingPluginException {
      // Safe no-op outside Android.
    } catch (error) {
      debugPrint('Bell preview stop failed: $error');
    }
  }

  @override
  Future<BellRingtoneBackup?> exportRingtone() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'exportRingtone',
      );
      if (result == null) return null;

      final base64 = result['base64']?.toString() ?? '';
      if (base64.isEmpty) return null;

      return BellRingtoneBackup(
        name: result['name']?.toString().trim().isNotEmpty == true
            ? result['name']!.toString().trim()
            : 'ringtone.audio',
        base64: base64,
      );
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Bell ringtone export failed: $error');
      return null;
    }
  }

  @override
  Future<BellRingtoneSelection?> restoreRingtone({
    required String name,
    required String base64,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'restoreRingtone',
        <String, dynamic>{
          'name': name,
          'base64': base64,
        },
      );
      if (result == null) return null;

      final uri = result['uri']?.toString() ?? '';
      if (uri.isEmpty) return null;

      return BellRingtoneSelection(
        uri: uri,
        name: result['name']?.toString().trim().isNotEmpty == true
            ? result['name']!.toString().trim()
            : name,
      );
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Bell ringtone restore failed: $error');
      return null;
    }
  }
}
