import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Route;
import 'package:webview_flutter/webview_flutter.dart';

import '../app_branding.dart';
import 'biometric_service.dart';
import 'contacts_service.dart';
import 'device_service.dart';
import 'file_service.dart';
import 'launcher_service.dart';
import 'location_service.dart';
import 'push_service.dart';
import 'qr_service.dart';
import 'storage_service.dart';

typedef NavigationBarStyleSetter = void Function(Map<String, dynamic> style);
typedef NavigationBarVisibleSetter = void Function(bool visible);
typedef NavigationBarTitleSetter = void Function(String title);
typedef NavigationBarButtonsSetter = void Function({bool? back, bool? scan});
typedef NavigationGoHomeHandler = Future<void> Function();

/// 在 WebView 中注入 `AppBridge` 通道，并在页面加载后安装 `window.App` 助手。
///
/// 网页中示例：
/// ```javascript
/// const v = await App.Services.StorageService.Get('myKey');
/// await App.Services.StorageService.Set('myKey', 'hello');
/// await App.Services.ToastService.Show('已保存');
/// await App.Services.LauncherService.OpenUrl('https://flutter.dev');
/// const loc = await App.Services.LocationService.Get();
/// const list = await App.Services.ContactsService.List(20);
/// const info = await App.Services.AppService.GetInfo();
/// const qr = await App.Services.QrService.Scan();
/// const file = await App.Services.FileService.PickFile();
/// const ok = await App.Services.BiometricService.Authenticate('请验证身份');
/// const device = await App.Services.DeviceService.GetInfo();
/// await App.NavigationBar.SetStyle({ title: '标题', backgroundColor: '#000000', foregroundColor: '#ffffff', fontSize: 18, fontWeight: 600 });
/// await App.NavigationBar.Hide();
/// ```
class AppJsBridge {
  AppJsBridge({
    required this.showSnackBar,
    required this.isMounted,
    required this.pushRoute,
    this.setNavigationBarStyle,
    this.setNavigationBarVisible,
    this.setNavigationBarTitle,
    this.setNavigationBarButtons,
    this.goHome,
    StorageService? storage,
    LauncherService? launcher,
    LocationService? location,
    ContactsService? contacts,
    QrService? qr,
    FileService? files,
    BiometricService? biometric,
    DeviceService? device,
  })  : _storage = storage ?? StorageService(),
        _launcher = launcher ?? LauncherService(),
        _location = location ?? LocationService(),
        _contacts = contacts ?? ContactsService(),
        _qr = qr ?? QrService(),
        _files = files ?? FileService(),
        _biometric = biometric ?? BiometricService(),
        _device = device ?? DeviceService();

  final void Function(String message) showSnackBar;
  final bool Function() isMounted;
  final Future<T?> Function<T>(Route<T> route) pushRoute;

  final NavigationBarStyleSetter? setNavigationBarStyle;
  final NavigationBarVisibleSetter? setNavigationBarVisible;
  final NavigationBarTitleSetter? setNavigationBarTitle;
  final NavigationBarButtonsSetter? setNavigationBarButtons;
  final NavigationGoHomeHandler? goHome;

  final StorageService _storage;
  final LauncherService _launcher;
  final LocationService _location;
  final ContactsService _contacts;
  final QrService _qr;
  final FileService _files;
  final BiometricService _biometric;
  final DeviceService _device;

  static const String _channelName = 'AppBridge';

  static const String _bootstrap = r'''
(function () {
  if (window.__flutterAppBridgeInstalled) return;
  window.__flutterAppBridgeInstalled = true;
  window.__appBridgePending = {};
  window.__appBridgeDeliver = function (id, payload) {
    var p = window.__appBridgePending[id];
    if (p) {
      if (payload.ok) p.resolve(payload.data);
      else p.reject(new Error(payload.error || 'unknown'));
      delete window.__appBridgePending[id];
    }
  };
  function call(ns, method, args) {
    return new Promise(function (resolve, reject) {
      var id = 'r' + Date.now() + '_' + Math.random().toString(36).slice(2);
      window.__appBridgePending[id] = { resolve: resolve, reject: reject };
      AppBridge.postMessage(JSON.stringify({ v: 1, id: id, ns: ns, method: method, args: args || {} }));
    });
  }

  window.App = window.App || {};
  window.App.Services = window.App.Services || {};
  window.App.Auth = window.App.Auth || {};
  window.App.NavigationBar = window.App.NavigationBar || {};
  window.App.Navigation = window.App.Navigation || {};

  window.App.Services.StorageService = {
    Get: function (key) { return call('storage', 'get', { key: key }); },
    Set: function (key, value) { return call('storage', 'set', { key: key, value: String(value) }); },
    Remove: function (key) { return call('storage', 'remove', { key: key }); },
    Keys: function () { return call('storage', 'keys', {}); },
    Clear: function () { return call('storage', 'clear', {}); },
  };

  window.App.Auth.SetAccessToken = function (token) {
    return call('auth', 'setAccessToken', { token: String(token || '') });
  };
  window.App.Auth.GetAccessToken = function () {
    return call('auth', 'getAccessToken', {});
  };
  window.App.Auth.ClearAccessToken = function () {
    return call('auth', 'clearAccessToken', {});
  };

  window.App.Services.ToastService = {
    Show: function (message) { return call('toast', 'show', { message: String(message) }); },
  };

  window.App.Services.LauncherService = {
    OpenUrl: function (url) { return call('launcher', 'openUrl', { url: String(url) }); },
  };

  window.App.Services.LocationService = {
    Get: function () { return call('location', 'get', {}); },
  };

  window.App.Services.ContactsService = {
    List: function (limit) { return call('contacts', 'list', { limit: limit == null ? 50 : Number(limit) }); },
  };

  window.App.Services.QrService = {
    Scan: function () { return call('qr', 'scan', {}); },
  };

  window.App.Services.FileService = {
    PickFile: function () { return call('files', 'pickFile', {}); },
    ReadText: function (path) { return call('files', 'readText', { path: String(path) }); },
    WriteText: function (path, text) { return call('files', 'writeText', { path: String(path), text: String(text) }); },
    Delete: function (path) { return call('files', 'delete', { path: String(path) }); },
    ListDir: function (path) { return call('files', 'listDir', { path: String(path) }); },
    GetAppDir: function () { return call('files', 'getAppDir', {}); },
  };

  window.App.Services.BiometricService = {
    IsSupported: function () { return call('biometric', 'isSupported', {}); },
    Authenticate: function (reason) { return call('biometric', 'authenticate', { reason: String(reason || '请验证身份') }); },
    GetAvailableBiometrics: function () { return call('biometric', 'getAvailableBiometrics', {}); },
  };

  window.App.Services.DeviceService = {
    GetInfo: function () { return call('device', 'getInfo', {}); },
  };

  window.App.Services.PushService = {
    GetRegistrationId: function () { return call('push', 'getRegistrationId', {}); },
  };

  window.App.Services.AppService = {
    GetInfo: function () { return call('app', 'getInfo', {}); },
  };

  window.App.NavigationBar.SetStyle = function (style) { return call('navigationBar', 'setStyle', { style: style || {} }); };
  window.App.NavigationBar.SetTitle = function (title) { return call('navigationBar', 'setTitle', { title: String(title || '') }); };
  // 动态控制顶部按钮显示：{ back: true/false, scan: true/false }
  window.App.NavigationBar.SetButtons = function (buttons) { return call('navigationBar', 'setButtons', { buttons: buttons || {} }); };
  window.App.NavigationBar.Show = function () { return call('navigationBar', 'setVisible', { visible: true }); };
  window.App.NavigationBar.Hide = function () { return call('navigationBar', 'setVisible', { visible: false }); };

  window.App.Navigation.GoHome = function () { return call('navigation', 'goHome', {}); };
})();
''';

  /// 注册 JS 通道（须在 [WebViewController.loadRequest] 之前调用）。
  void registerChannel(WebViewController controller) {
    controller.addJavaScriptChannel(
      _channelName,
      onMessageReceived: (JavaScriptMessage message) {
        unawaited(_handleMessage(controller, message.message));
      },
    );
  }

  /// 页面加载完成后注入 `window.App`（在 [NavigationDelegate.onPageFinished] 中调用）。
  Future<void> injectBootstrap(WebViewController controller) async {
    if (!isMounted()) return;
    try {
      await controller.runJavaScript(_bootstrap);
    } catch (e, st) {
      debugPrint('AppJsBridge inject failed: $e\n$st');
    }
  }

  Future<void> _reply(
    WebViewController controller,
    String? id,
    bool ok,
    Object? data,
    String? error,
  ) async {
    if (id == null || id.isEmpty || !isMounted()) return;
    final payload = jsonEncode({'ok': ok, 'data': data, 'error': error});
    try {
      await controller.runJavaScript(
        'try{window.__appBridgeDeliver(${jsonEncode(id)}, JSON.parse(${jsonEncode(payload)}));}catch(e){console.error(e);}',
      );
    } catch (e, st) {
      debugPrint('AppJsBridge reply failed: $e\n$st');
    }
  }

  Future<void> _handleMessage(WebViewController controller, String raw) async {
    Map<String, dynamic>? decodedMsg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) decodedMsg = decoded;
    } catch (_) {
      return;
    }
    final msg = decodedMsg;
    if (msg == null) return;

    final id = msg['id'] as String?;
    final ns = msg['ns'] as String?;
    final method = msg['method'] as String?;
    final args = msg['args'];
    final argMap = args is Map<String, dynamic> ? args : <String, dynamic>{};

    try {
      final data = await _dispatch(ns, method, argMap);
      await _reply(controller, id, true, data, null);
    } catch (e) {
      await _reply(controller, id, false, null, e.toString());
    }
  }

  Future<Object?> _dispatch(String? ns, String? method, Map<String, dynamic> args) async {
    switch (ns) {
      case 'storage':
        return _storageDispatch(method, args);
      case 'auth':
        return _authDispatch(method, args);
      case 'toast':
        return _toastDispatch(method, args);
      case 'launcher':
        return _launcherDispatch(method, args);
      case 'location':
        return _locationDispatch(method, args);
      case 'contacts':
        return _contactsDispatch(method, args);
      case 'qr':
        return _qrDispatch(method, args);
      case 'files':
        return _filesDispatch(method, args);
      case 'biometric':
        return _biometricDispatch(method, args);
      case 'device':
        return _deviceDispatch(method, args);
      case 'push':
        return _pushDispatch(method, args);
      case 'app':
        return _appDispatch(method, args);
      case 'navigationBar':
        return _navigationBarDispatch(method, args);
      case 'navigation':
        return _navigationDispatch(method, args);
      default:
        throw UnsupportedError('未知命名空间: $ns');
    }
  }

  Future<Object?> _storageDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'get':
        final key = args['key'] as String?;
        if (key == null || key.isEmpty) throw ArgumentError('缺少 key');
        return await _storage.getString(key);
      case 'set':
        final key = args['key'] as String?;
        final value = args['value'] as String?;
        if (key == null || key.isEmpty) throw ArgumentError('缺少 key');
        await _storage.setString(key, value ?? '');
        return null;
      case 'remove':
        final key = args['key'] as String?;
        if (key == null || key.isEmpty) throw ArgumentError('缺少 key');
        await _storage.remove(key);
        return null;
      case 'keys':
        return await _storage.getKeys();
      case 'clear':
        await _storage.clear();
        return null;
      default:
        throw UnsupportedError('storage.$method');
    }
  }

  Future<Object?> _authDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setAccessToken':
        final token = (args['token'] as String? ?? '').trim();
        await _storage.setString('access_token', token);
        return true;
      case 'getAccessToken':
        return await _storage.getString('access_token');
      case 'clearAccessToken':
        await _storage.remove('access_token');
        return true;
      default:
        throw UnsupportedError('auth.$method');
    }
  }

  Future<Object?> _toastDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'show') throw UnsupportedError('toast.$method');
    final message = args['message'] as String? ?? '';
    if (!isMounted()) return null;
    showSnackBar(message);
    return null;
  }

  Future<Object?> _launcherDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'openUrl') throw UnsupportedError('launcher.$method');
    final url = args['url'] as String? ?? '';
    await _launcher.openUrl(url);
    return true;
  }

  Future<Object?> _locationDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'get') throw UnsupportedError('location.$method');
    return await _location.getCurrentPosition();
  }

  Future<Object?> _contactsDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'list') throw UnsupportedError('contacts.$method');
    final limit = (args['limit'] as num?)?.toInt() ?? 50;
    return await _contacts.listContacts(limit: limit);
  }

  Future<Object?> _qrDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'scan') throw UnsupportedError('qr.$method');
    final text = await _qr.scan(pushRoute: pushRoute);
    return {'text': text};
  }

  Future<Object?> _filesDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'pickFile':
        return await _files.pickFile();
      case 'readText':
        final path = args['path'] as String?;
        if (path == null || path.isEmpty) throw ArgumentError('缺少 path');
        return await _files.readText(path);
      case 'writeText':
        final path = args['path'] as String?;
        final text = args['text'] as String? ?? '';
        if (path == null || path.isEmpty) throw ArgumentError('缺少 path');
        await _files.writeText(path, text);
        return true;
      case 'delete':
        final path = args['path'] as String?;
        if (path == null || path.isEmpty) throw ArgumentError('缺少 path');
        await _files.delete(path);
        return true;
      case 'listDir':
        final path = args['path'] as String?;
        if (path == null || path.isEmpty) throw ArgumentError('缺少 path');
        return await _files.listDir(path);
      case 'getAppDir':
        return await _files.getAppDir();
      default:
        throw UnsupportedError('files.$method');
    }
  }

  Future<Object?> _biometricDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isSupported':
        return await _biometric.isSupported();
      case 'getAvailableBiometrics':
        return (await _biometric.getAvailableBiometrics()).map((e) => e.name).toList();
      case 'authenticate':
        final reason = args['reason'] as String? ?? '请验证身份';
        return await _biometric.authenticate(reason: reason);
      default:
        throw UnsupportedError('biometric.$method');
    }
  }

  Future<Object?> _deviceDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'getInfo') throw UnsupportedError('device.$method');
    return await _device.getInfo();
  }

  Future<Object?> _pushDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'getRegistrationId') throw UnsupportedError('push.$method');
    return await PushService.getRegistrationId();
  }

  Future<Object?> _appDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'getInfo') throw UnsupportedError('app.$method');
    return {
      'displayName': kAppDisplayName,
    };
  }

  Future<Object?> _navigationBarDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setStyle':
        final style = args['style'];
        if (style is! Map<String, dynamic>) throw ArgumentError('style 必须是对象');
        setNavigationBarStyle?.call(style);
        return true;
      case 'setTitle':
        final title = args['title'] as String? ?? '';
        setNavigationBarTitle?.call(title);
        return true;
      case 'setButtons':
        final buttons = args['buttons'];
        if (buttons is! Map<String, dynamic>) throw ArgumentError('buttons 必须是对象');
        final back = buttons['back'];
        final scan = buttons['scan'];
        setNavigationBarButtons?.call(
          back: back is bool ? back : null,
          scan: scan is bool ? scan : null,
        );
        return true;
      case 'setVisible':
        final visible = args['visible'];
        if (visible is! bool) throw ArgumentError('visible 必须是 boolean');
        setNavigationBarVisible?.call(visible);
        return true;
      default:
        throw UnsupportedError('navigationBar.$method');
    }
  }

  Future<Object?> _navigationDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'goHome') throw UnsupportedError('navigation.$method');
    final handler = goHome;
    if (handler == null) {
      throw UnsupportedError('未配置 GoHome 处理器');
    }
    await handler();
    return true;
  }
}

