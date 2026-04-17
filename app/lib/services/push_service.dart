import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:permission_handler/permission_handler.dart';

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
    if (resolved.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'PushService: 跳过极光初始化（无 AppKey）。请在 /v1/app 返回 jpush_app_key，'
          '或在 android/gradle.properties 配置 jpush.appKey，或构建时 --dart-define=JPUSH_APP_KEY=…',
        );
      }
      return;
    }

    if (!_handlersBound) {
      _jpush.addEventHandler(
        onReceiveNotification: (Map<String, dynamic> message) async {},
        onOpenNotification: (Map<String, dynamic> message) async {},
        onReceiveMessage: (Map<String, dynamic> message) async {},
      );
      _handlersBound = true;
    }

    if (_initializedAppKey != resolved) {
      // 合规：允许采集（需在 init 前；见极光 JCore 说明）
      _jpush.setAuth(enable: true);

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
      if (kDebugMode) {
        unawaited(_logRegistrationIdDelayed());
      }
    }

    // 每次启动都检查：用户曾拒绝时，之后仍可能去系统设置打开通知
    await _ensurePostNotificationsGranted();
  }

  /// Android 13+ 必须运行时授予通知权限，否则通知栏不展示。
  static Future<void> _ensurePostNotificationsGranted() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return;
    await Permission.notification.request();
  }

  static Future<void> _logRegistrationIdDelayed() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final rid = await getRegistrationId();
    debugPrint('[JPush] registrationId=$rid （请到极光控制台核对包名与 AppKey）');
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
