import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Route;
import 'package:webview_flutter/webview_flutter.dart';

import '../app_branding.dart';
import '../utils/hex_color.dart';
import 'app_settings_service.dart';
import 'biometric_service.dart';
import 'bluetooth_bridge_service.dart';
import 'calendar_bridge_service.dart';
import 'contacts_service.dart';
import 'device_service.dart';
import 'gallery_save_service.dart';
import 'file_service.dart';
import 'launcher_service.dart';
import 'media_pick_service.dart';
import 'location_service.dart';
import 'nfc_bridge_service.dart';
import 'network_service.dart';
import 'push_service.dart';
import 'qr_service.dart';
import 'share_service.dart';
import 'storage_service.dart';
import 'telephony_service.dart';

typedef NavigationBarStyleSetter = void Function(Map<String, dynamic> style);
typedef NavigationBarVisibleSetter = void Function(bool visible);
typedef NavigationBarTitleSetter = void Function(String title);
typedef NavigationBarButtonsSetter = void Function({bool? back, bool? scan});
typedef NavigationGoHomeHandler = Future<void> Function();
typedef SystemUiImmersiveChanged = void Function(bool immersive);
/// `null` 表示恢复为启动配置中的默认衬色（接口 / dart-define）。
typedef ChromeBackgroundColorChanged = void Function(Color? color);

/// 在 WebView 中注入 `AppBridge` 通道，并在页面加载后安装 `window.MobileApp` 助手。
///
/// 网页中示例：
/// ```javascript
/// const v = await MobileApp.Services.StorageService.Get('myKey');
/// await MobileApp.Services.StorageService.Set('myKey', 'hello');
/// await MobileApp.Services.ToastService.Show('已保存');
/// await MobileApp.Services.LauncherService.OpenUrl('https://flutter.dev');
/// const loc = await MobileApp.Services.LocationService.Get();
/// const list = await MobileApp.Services.ContactsService.List(20);
/// await MobileApp.Services.ContactsService.Save({ displayName: '张三', phones: ['13800138000'], emails: ['a@b.com'] });
/// const picked = await MobileApp.Services.ContactsService.Pick();
/// const info = await MobileApp.Services.AppService.GetInfo();
/// const qr = await MobileApp.Services.QrService.Scan();
/// const file = await MobileApp.Services.FileService.PickFile();
/// const ok = await MobileApp.Services.BiometricService.Authenticate('请验证身份');
/// const device = await MobileApp.Services.DeviceService.GetInfo();
/// await MobileApp.NavigationBar.SetStyle({ title: '标题', backgroundColor: '#000000', foregroundColor: '#ffffff', fontSize: 18, fontWeight: 600 });
/// await MobileApp.NavigationBar.Hide();
/// // 两种系统 UI：false = 京东式 edge-to-edge（状态栏叠字）；true = 沉浸（隐藏系统栏，全屏）
/// await MobileApp.Window.SetImmersive(false);
/// await MobileApp.Window.SetImmersive(true);
/// await MobileApp.Window.SetChromeBackgroundColor('#1677FF');
/// await MobileApp.Window.SetChromeBackgroundColor('');
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
    this.onSystemUiImmersiveChanged,
    this.onChromeBackgroundColorChanged,
    StorageService? storage,
    LauncherService? launcher,
    LocationService? location,
    ContactsService? contacts,
    QrService? qr,
    FileService? files,
    BiometricService? biometric,
    DeviceService? device,
    ShareService? share,
    NetworkService? network,
    MediaPickService? mediaPick,
    AppSettingsService? appSettings,
    GallerySaveService? gallery,
    TelephonyService? telephony,
    CalendarBridgeService? calendar,
    NfcBridgeService? nfc,
    BluetoothBridgeService? bluetooth,
  })  : _storage = storage ?? StorageService(),
        _launcher = launcher ?? LauncherService(),
        _location = location ?? LocationService(),
        _contacts = contacts ?? ContactsService(),
        _qr = qr ?? QrService(),
        _files = files ?? FileService(),
        _biometric = biometric ?? BiometricService(),
        _device = device ?? DeviceService(),
        _share = share ?? ShareService(),
        _network = network ?? NetworkService(),
        _mediaPick = mediaPick ?? MediaPickService(),
        _appSettings = appSettings ?? AppSettingsService(),
        _gallery = gallery ?? GallerySaveService(),
        _telephony = telephony ?? TelephonyService(),
        _calendar = calendar ?? CalendarBridgeService(),
        _nfc = nfc ?? NfcBridgeService(),
        _bluetooth = bluetooth ?? BluetoothBridgeService();

  final void Function(String message) showSnackBar;
  final bool Function() isMounted;
  final Future<T?> Function<T>(Route<T> route) pushRoute;

  final NavigationBarStyleSetter? setNavigationBarStyle;
  final NavigationBarVisibleSetter? setNavigationBarVisible;
  final NavigationBarTitleSetter? setNavigationBarTitle;
  final NavigationBarButtonsSetter? setNavigationBarButtons;
  final NavigationGoHomeHandler? goHome;
  /// 与 [Window.SetImmersive] 同步：京东式 edge-to-edge vs 沉浸全屏。
  final SystemUiImmersiveChanged? onSystemUiImmersiveChanged;
  /// 与 [Window.SetChromeBackgroundColor] 同步，更新衬色与系统栏图标对比度。
  final ChromeBackgroundColorChanged? onChromeBackgroundColorChanged;

  final StorageService _storage;
  final LauncherService _launcher;
  final LocationService _location;
  final ContactsService _contacts;
  final QrService _qr;
  final FileService _files;
  final BiometricService _biometric;
  final DeviceService _device;
  final ShareService _share;
  final NetworkService _network;
  final MediaPickService _mediaPick;
  final AppSettingsService _appSettings;
  final GallerySaveService _gallery;
  final TelephonyService _telephony;
  final CalendarBridgeService _calendar;
  final NfcBridgeService _nfc;
  final BluetoothBridgeService _bluetooth;

  WebViewController? _webViewController;
  StreamSubscription<Map<String, Object?>>? _locationWatchSub;

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

  window.MobileApp = window.MobileApp || {};
  window.MobileApp.Services = window.MobileApp.Services || {};
  window.MobileApp.Auth = window.MobileApp.Auth || {};
  window.MobileApp.NavigationBar = window.MobileApp.NavigationBar || {};
  window.MobileApp.Navigation = window.MobileApp.Navigation || {};
  window.MobileApp.Window = window.MobileApp.Window || {};

  window.MobileApp.Services.StorageService = {
    Get: function (key) { return call('storage', 'get', { key: key }); },
    Set: function (key, value) { return call('storage', 'set', { key: key, value: String(value) }); },
    Remove: function (key) { return call('storage', 'remove', { key: key }); },
    Keys: function () { return call('storage', 'keys', {}); },
    Clear: function () { return call('storage', 'clear', {}); },
  };

  window.MobileApp.Auth.SetAccessToken = function (token) {
    return call('auth', 'setAccessToken', { token: String(token || '') });
  };
  window.MobileApp.Auth.GetAccessToken = function () {
    return call('auth', 'getAccessToken', {});
  };
  window.MobileApp.Auth.ClearAccessToken = function () {
    return call('auth', 'clearAccessToken', {});
  };

  window.MobileApp.Services.ToastService = {
    Show: function (message) { return call('toast', 'show', { message: String(message) }); },
  };

  window.MobileApp.Services.LauncherService = {
    OpenUrl: function (url) { return call('launcher', 'openUrl', { url: String(url) }); },
  };

  window.MobileApp.Services.LocationService = {
    Get: function () { return call('location', 'get', {}); },
    StartWatch: function (opts) {
      var o = opts || {};
      return call('location', 'startWatch', {
        distanceFilterM: o.distanceFilterM == null ? 0 : Number(o.distanceFilterM),
        intervalSec: o.intervalSec == null ? 2 : Number(o.intervalSec),
        foregroundService: Boolean(o.foregroundService),
      });
    },
    StopWatch: function () { return call('location', 'stopWatch', {}); },
  };

  window.MobileApp.Services.ContactsService = {
    List: function (limit) { return call('contacts', 'list', { limit: limit == null ? 50 : Number(limit) }); },
    Save: function (data) { return call('contacts', 'save', { data: data || {} }); },
    Pick: function () { return call('contacts', 'pick', {}); },
  };

  window.MobileApp.Services.QrService = {
    Scan: function () { return call('qr', 'scan', {}); },
  };

  window.MobileApp.Services.FileService = {
    PickFile: function () { return call('files', 'pickFile', {}); },
    ReadText: function (path) { return call('files', 'readText', { path: String(path) }); },
    WriteText: function (path, text) { return call('files', 'writeText', { path: String(path), text: String(text) }); },
    Delete: function (path) { return call('files', 'delete', { path: String(path) }); },
    ListDir: function (path) { return call('files', 'listDir', { path: String(path) }); },
    GetAppDir: function () { return call('files', 'getAppDir', {}); },
  };

  window.MobileApp.Services.BiometricService = {
    IsSupported: function () { return call('biometric', 'isSupported', {}); },
    Authenticate: function (reason) { return call('biometric', 'authenticate', { reason: String(reason || '请验证身份') }); },
    GetAvailableBiometrics: function () { return call('biometric', 'getAvailableBiometrics', {}); },
  };

  window.MobileApp.Services.DeviceService = {
    GetInfo: function () { return call('device', 'getInfo', {}); },
  };

  window.MobileApp.Services.PushService = {
    GetRegistrationId: function () { return call('push', 'getRegistrationId', {}); },
  };

  window.MobileApp.Services.AppService = {
    GetInfo: function () { return call('app', 'getInfo', {}); },
  };

  window.MobileApp.Services.ShareService = {
    ShareText: function (text, subject) {
      return call('share', 'shareText', { text: String(text || ''), subject: subject == null ? '' : String(subject) });
    },
    ShareUri: function (url) { return call('share', 'shareUri', { url: String(url || '') }); },
  };

  window.MobileApp.Services.ClipboardService = {
    SetText: function (text) { return call('clipboard', 'setText', { text: String(text || '') }); },
    GetText: function () { return call('clipboard', 'getText', {}); },
  };

  window.MobileApp.Services.NetworkService = {
    GetStatus: function () { return call('network', 'getStatus', {}); },
  };

  window.MobileApp.Services.MediaService = {
    PickFromGallery: function () { return call('media', 'pickGallery', {}); },
    TakePhoto: function () { return call('media', 'takePhoto', {}); },
  };

  window.MobileApp.Services.SettingsService = {
    OpenAppSettings: function () { return call('settings', 'openApp', {}); },
  };

  window.MobileApp.Services.GalleryService = {
    SaveImageFromPath: function (path) { return call('gallery', 'saveImagePath', { path: String(path || '') }); },
    SaveImageFromBase64: function (base64, name) {
      return call('gallery', 'saveImageBase64', { base64: String(base64 || ''), name: name == null ? 'image' : String(name) });
    },
  };

  window.MobileApp.Services.TelephonyService = {
    Dial: function (phone) { return call('telephony', 'dial', { phone: String(phone || '') }); },
    SendSms: function (phone, body) {
      return call('telephony', 'sendSms', { phone: String(phone || ''), body: body == null ? '' : String(body) });
    },
  };

  window.MobileApp.Services.CalendarService = {
    AddEvent: function (o) { return call('calendar', 'addEvent', o || {}); },
  };

  window.MobileApp.Services.NfcService = {
    GetAvailability: function () { return call('nfc', 'availability', {}); },
    ReadNdef: function (timeoutSec) { return call('nfc', 'readNdef', { timeoutSec: timeoutSec == null ? 30 : Number(timeoutSec) }); },
  };

  window.MobileApp.Services.BluetoothService = {
    GetStatus: function () { return call('bluetooth', 'status', {}); },
    Scan: function (timeoutSec) { return call('bluetooth', 'scan', { timeoutSec: timeoutSec == null ? 8 : Number(timeoutSec) }); },
  };

  window.MobileApp.NavigationBar.SetStyle = function (style) { return call('navigationBar', 'setStyle', { style: style || {} }); };
  window.MobileApp.NavigationBar.SetTitle = function (title) { return call('navigationBar', 'setTitle', { title: String(title || '') }); };
  // 动态控制顶部按钮显示：{ back: true/false, scan: true/false }
  window.MobileApp.NavigationBar.SetButtons = function (buttons) { return call('navigationBar', 'setButtons', { buttons: buttons || {} }); };
  window.MobileApp.NavigationBar.Show = function () { return call('navigationBar', 'setVisible', { visible: true }); };
  window.MobileApp.NavigationBar.Hide = function () { return call('navigationBar', 'setVisible', { visible: false }); };

  window.MobileApp.Navigation.GoHome = function () { return call('navigation', 'goHome', {}); };

  // 默认应用已为 edge-to-edge；false：保持/恢复京东式叠字；true：沉浸全屏（immersiveSticky）
  window.MobileApp.Window.SetImmersive = function (enabled) {
    return call('window', 'setImmersive', { enabled: Boolean(enabled) });
  };
  window.MobileApp.Window.SetChromeBackgroundColor = function (color) {
    return call('window', 'setChromeBackgroundColor', { color: String(color == null ? '' : color) });
  };
})();
''';

  /// 注册 JS 通道（须在 [WebViewController.loadRequest] 之前调用）。
  void registerChannel(WebViewController controller) {
    _webViewController = controller;
    controller.addJavaScriptChannel(
      _channelName,
      onMessageReceived: (JavaScriptMessage message) {
        unawaited(_handleMessage(controller, message.message));
      },
    );
  }

  /// 页面加载完成后注入 `window.MobileApp` 与桥接脚本（在 [NavigationDelegate.onPageFinished] 中调用）。
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
      case 'gallery':
        return _galleryDispatch(method, args);
      case 'telephony':
        return _telephonyDispatch(method, args);
      case 'calendar':
        return _calendarDispatch(method, args);
      case 'nfc':
        return _nfcDispatch(method, args);
      case 'bluetooth':
        return _bluetoothDispatch(method, args);
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
      case 'share':
        return _shareDispatch(method, args);
      case 'clipboard':
        return _clipboardDispatch(method, args);
      case 'network':
        return _networkDispatch(method, args);
      case 'media':
        return _mediaDispatch(method, args);
      case 'settings':
        return _settingsDispatch(method, args);
      case 'navigationBar':
        return _navigationBarDispatch(method, args);
      case 'navigation':
        return _navigationDispatch(method, args);
      case 'window':
        return _windowDispatch(method, args);
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
    switch (method) {
      case 'get':
        return await _location.getCurrentPosition();
      case 'startWatch':
        final distance = (args['distanceFilterM'] as num?)?.toInt() ?? 0;
        final intervalSec = (args['intervalSec'] as num?)?.toInt() ?? 2;
        final foreground = args['foregroundService'] == true;
        await _locationWatchSub?.cancel();
        _locationWatchSub = _location
            .watchPosition(
              distanceFilterM: distance,
              intervalSec: intervalSec,
              androidForegroundService: foreground,
            )
            .listen(
              (m) => unawaited(_emitLocationUpdate(m)),
              onError: (Object e, StackTrace st) => debugPrint('location watch: $e'),
            );
        return true;
      case 'stopWatch':
        await _locationWatchSub?.cancel();
        _locationWatchSub = null;
        return true;
      default:
        throw UnsupportedError('location.$method');
    }
  }

  Future<void> _emitLocationUpdate(Map<String, Object?> loc) async {
    final c = _webViewController;
    if (c == null || !isMounted()) return;
    final json = jsonEncode(loc);
    try {
      await c.runJavaScript(
        'try{if(window.MobileApp&&typeof window.MobileApp.onLocationUpdate==="function"){window.MobileApp.onLocationUpdate($json);}}catch(e){console.error(e);}',
      );
    } catch (e, st) {
      debugPrint('AppJsBridge location emit: $e\n$st');
    }
  }

  Future<Object?> _galleryDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'saveImagePath':
        final path = args['path'] as String? ?? '';
        if (path.isEmpty) throw ArgumentError('缺少 path');
        return await _gallery.saveImageFromPath(path);
      case 'saveImageBase64':
        final b64 = args['base64'] as String? ?? '';
        if (b64.isEmpty) throw ArgumentError('缺少 base64');
        final rawName = args['name'] as String?;
        final name = (rawName == null || rawName.trim().isEmpty) ? 'image' : rawName.trim();
        return await _gallery.saveImageFromBase64(b64, name: name);
      default:
        throw UnsupportedError('gallery.$method');
    }
  }

  Future<Object?> _telephonyDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'dial':
        return await _telephony.dial(args['phone'] as String? ?? '');
      case 'sendSms':
        return await _telephony.sendSms(
          args['phone'] as String? ?? '',
          body: args['body'] as String?,
        );
      default:
        throw UnsupportedError('telephony.$method');
    }
  }

  Future<Object?> _calendarDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'addEvent') throw UnsupportedError('calendar.$method');
    final startMs = (args['startMs'] as num?)?.toInt();
    final endMs = (args['endMs'] as num?)?.toInt();
    if (startMs == null || endMs == null) throw ArgumentError('startMs / endMs 必填');
    return await _calendar.addEvent(
      title: args['title'] as String? ?? '',
      description: args['description'] as String?,
      location: args['location'] as String?,
      startMs: startMs,
      endMs: endMs,
      allDay: args['allDay'] == true,
    );
  }

  Future<Object?> _nfcDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'availability':
        return await _nfc.checkAvailability();
      case 'readNdef':
        final t = (args['timeoutSec'] as num?)?.toInt() ?? 30;
        return await _nfc.readNdefOnce(timeoutSec: t);
      default:
        throw UnsupportedError('nfc.$method');
    }
  }

  Future<Object?> _bluetoothDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'status':
        return await _bluetooth.getStatus();
      case 'scan':
        final t = (args['timeoutSec'] as num?)?.toInt() ?? 8;
        return await _bluetooth.scan(timeoutSec: t);
      default:
        throw UnsupportedError('bluetooth.$method');
    }
  }

  Future<Object?> _contactsDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'list':
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
        return await _contacts.listContacts(limit: limit);
      case 'save':
        final data = args['data'];
        if (data is! Map<String, dynamic>) throw ArgumentError('data 必须是对象');
        return await _contacts.saveContact(data);
      case 'pick':
        return await _contacts.pickContact();
      default:
        throw UnsupportedError('contacts.$method');
    }
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

  Future<Object?> _shareDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'shareText':
        final text = args['text'] as String? ?? '';
        final subjectRaw = args['subject'] as String? ?? '';
        final subject = subjectRaw.trim().isEmpty ? null : subjectRaw;
        await _share.shareText(text, subject: subject);
        return true;
      case 'shareUri':
        await _share.shareUri(args['url'] as String? ?? '');
        return true;
      default:
        throw UnsupportedError('share.$method');
    }
  }

  Future<Object?> _clipboardDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setText':
        final text = args['text'] as String? ?? '';
        await Clipboard.setData(ClipboardData(text: text));
        return true;
      case 'getText':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        return data?.text;
      default:
        throw UnsupportedError('clipboard.$method');
    }
  }

  Future<Object?> _networkDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'getStatus') throw UnsupportedError('network.$method');
    return await _network.getStatus();
  }

  Future<Object?> _mediaDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'pickGallery':
        return await _mediaPick.pickFromGallery();
      case 'takePhoto':
        return await _mediaPick.takePhoto();
      default:
        throw UnsupportedError('media.$method');
    }
  }

  Future<Object?> _settingsDispatch(String? method, Map<String, dynamic> args) async {
    if (method != 'openApp') throw UnsupportedError('settings.$method');
    await _appSettings.openAppSettings();
    return true;
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

  Future<Object?> _windowDispatch(String? method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setImmersive':
        final enabled = args['enabled'] == true;
        if (enabled) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        if (isMounted()) {
          onSystemUiImmersiveChanged?.call(enabled);
        }
        return true;
      case 'setChromeBackgroundColor':
        final raw = (args['color'] as String? ?? '').trim();
        if (raw.isEmpty) {
          if (isMounted()) onChromeBackgroundColorChanged?.call(null);
          return true;
        }
        final parsed = parseHexColor(raw);
        if (parsed == null) throw ArgumentError('无效的 color，需为 #RGB / #RRGGBB / #AARRGGBB');
        if (isMounted()) onChromeBackgroundColorChanged?.call(parsed);
        return true;
      default:
        throw UnsupportedError('window.$method');
    }
  }
}

