import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class AppShareService {
  Future<bool> shareText(String text);
}

class MethodChannelAppShareService implements AppShareService {
  MethodChannelAppShareService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('school_schedule/share');

  final MethodChannel _channel;

  @override
  Future<bool> shareText(String text) async {
    try {
      return await _channel.invokeMethod<bool>(
            'shareText',
            <String, dynamic>{'text': text},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('App share failed: $error');
      return false;
    }
  }
}
