import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class BackupFileService {
  Future<bool> shareBackup({
    required String fileName,
    required String json,
  });

  Future<String?> pickBackup();
}

class MethodChannelBackupFileService implements BackupFileService {
  MethodChannelBackupFileService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('school_schedule/backup');

  final MethodChannel _channel;

  @override
  Future<bool> shareBackup({
    required String fileName,
    required String json,
  }) async {
    try {
      return await _channel.invokeMethod<bool>(
            'shareBackup',
            <String, dynamic>{
              'fileName': fileName,
              'json': json,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('Backup sharing failed: $error');
      return false;
    }
  }

  @override
  Future<String?> pickBackup() async {
    try {
      return await _channel.invokeMethod<String>('pickBackup');
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Backup picker failed: $error');
      return null;
    }
  }
}
