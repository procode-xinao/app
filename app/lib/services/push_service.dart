import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';

class PushService {
  PushService._();

  static const String _fallbackAppKey = String.fromEnvironment(
    'JPUSH_APP_KEY',
    defaultValue: '',
  );
  static const String _channel = String.fromEnvironment(
    'JPUSH_CHANNEL',
    defaultValue: 'default',
  );
  static const bool _production = bool.fromEnvironment(
    'JPUSH_PRODUCTION',
    defaultValue: false,
  );
  static const bool _debug = bool.fromEnvironment(
    'JPUSH_DEBUG',
    defaultValue: true,
  );

  static final JPushFlutterInterface _jpush = JPush.newJPush();
  static bool _handlersBound = false;
  static String? _initializedAppKey;

  static JPushFlutterInterface get client => _jpush;

  static Future<void> ensureInitialized({String? appKey}) async {
    final resolved = (appKey ?? '').trim().isNotEmpty ? appKey!.trim() : _fallbackAppKey;
    if (resolved.isEmpty) return;

    if (!_handlersBound) {
      _jpush.addEventHandler(
        onReceiveNotification: (Map<String, dynamic> message) async {},
        onOpenNotification: (Map<String, dynamic> message) async {},
        onReceiveMessage: (Map<String, dynamic> message) async {},
      );
      _handlersBound = true;
    }

    if (_initializedAppKey == resolved) return;

    _jpush.setup(
      appKey: resolved,
      channel: _channel,
      production: _production,
      debug: _debug,
    );
    _jpush.applyPushAuthority(
      const NotificationSettingsIOS(sound: true, alert: true, badge: true),
    );
    _initializedAppKey = resolved;
  }

  static Future<String?> getRegistrationId() async {
    try {
      final dynamic value = await _jpush.getRegistrationID();
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}
