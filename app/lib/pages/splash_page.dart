import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_bootstrap_service.dart';
import '../services/app_js_bridge.dart';
import '../services/push_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_web_shell.dart';

/// 启动：拉取配置 → WebView 打开主入口。
///
/// 系统 UI 两种模式（由 **`MobileApp.Window.SetImmersive`**）：
/// - **`false`（默认）**：**edge-to-edge**（京东式叠字），与 `main.dart` 中 `SystemUiMode.edgeToEdge` 一致；透明状态栏叠字，顶边不包 SafeArea。
/// - **`true`**：**沉浸/全屏**，`immersiveSticky`，隐藏系统栏，WebView 四边贴屏。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AppBootstrapService _service = AppBootstrapService();
  final StorageService _storage = StorageService();
  AppBootstrapResult? _bootstrap;
  AppJsBridge? _bridge;
  String? _error;

  WebViewController? _webController;
  /// `true`：沉浸全屏；`false`：京东式 edge-to-edge。
  bool _immersiveChrome = false;
  /// 桥接 [MobileApp.Window.SetChromeBackgroundColor] 覆盖；`null` 用启动配置默认色。
  Color? _chromeColorOverride;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final bootstrap = await _service.load();
      await PushService.ensureInitialized(appKey: bootstrap.jpushAppKey);
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _immersiveChrome = false;
      });
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      _ensureBridge();
      _scheduleApplySystemChrome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _ensureBridge() {
    final b = _bootstrap;
    if (b == null || _bridge != null) return;
    _bridge = AppJsBridge(
      showSnackBar: _showSnackBar,
      isMounted: () => mounted,
      pushRoute: <T>(Route<T> route) => Navigator.of(context).push(route),
      goHome: _goHome,
      onSystemUiImmersiveChanged: (immersive) {
        if (!mounted) return;
        setState(() => _immersiveChrome = immersive);
        _scheduleApplySystemChrome();
      },
      onChromeBackgroundColorChanged: (color) {
        if (!mounted) return;
        setState(() => _chromeColorOverride = color);
        _scheduleApplySystemChrome();
        unawaited(_syncWebViewChrome());
      },
    );
  }

  Future<void> _goHome() async {
    final c = _webController;
    final b = _bootstrap;
    if (c == null || b == null || !mounted) return;
    await c.loadRequest(Uri.parse(b.entryUrl));
    final token = await _storage.getString('access_token');
    final t = token?.trim();
    if (t != null && t.isNotEmpty) {
      await _setAccessTokenToWebStorage(c, t);
    }
  }

  Future<void> _setAccessTokenToWebStorage(
    WebViewController controller,
    String token,
  ) async {
    final escaped = token
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    await controller.runJavaScript("localStorage.setItem('access_token', '$escaped');");
  }

  /// Android 全面屏左缘右滑 / 实体返回键：优先 WebView 历史后退，否则退出应用。
  Future<void> _handleSystemBack() async {
    final c = _webController;
    if (c != null) {
      try {
        if (await c.canGoBack()) {
          await c.goBack();
          return;
        }
      } catch (e, st) {
        debugPrint('SplashPage WebView goBack: $e\n$st');
      }
    } else if (_bootstrap != null) {
      // 控制器尚未就绪时勿当作「无历史」而直接退出
      return;
    }
    if (!mounted) return;
    await SystemNavigator.pop();
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _scheduleApplySystemChrome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applySystemChrome();
    });
  }

  Color _effectiveChromeColor(AppBootstrapResult b) => _chromeColorOverride ?? b.topBackgroundColor;

  Future<void> _syncWebViewChrome() async {
    final w = _webController;
    final b = _bootstrap;
    if (w == null || b == null) return;
    await w.setBackgroundColor(_effectiveChromeColor(b));
  }

  /// 沉浸：透明系统栏（栏已隐藏）；京东式：透明叠字，图标明暗随衬色亮度。
  void _applySystemChrome() {
    final b = _bootstrap;
    if (b == null) return;
    if (_immersiveChrome) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
      return;
    }
    final bg = _effectiveChromeColor(b);
    final lightBg = bg.computeLuminance() > 0.5;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: lightBg ? Brightness.dark : Brightness.light,
        statusBarBrightness: lightBg ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: lightBg ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = _bootstrap;
    if (bootstrap == null) {
      if (_error != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('启动失败：$_error', textAlign: TextAlign.center),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.expand(),
      );
    }

    final bridge = _bridge;
    final shell = AppWebShell(
      initialUrl: bootstrap.entryUrl,
      bridge: bridge,
      chromeBackgroundColor: _effectiveChromeColor(bootstrap),
      showLoadingIndicator: false,
      onControllerReady: (c) async {
        _webController = c;
        await c.setBackgroundColor(_effectiveChromeColor(bootstrap));
        final token = await _storage.getString('access_token');
        final normalized = token?.trim();
        if (normalized == null || normalized.isEmpty) return;
        final valid = await _service.validateToken(
          serverBaseUrl: bootstrap.serverBaseUrl,
          token: normalized,
        );
        if (!mounted || !valid) return;
        await _setAccessTokenToWebStorage(c, normalized);
      },
    );
    // 京东式：顶不包 SafeArea，左右底避让；沉浸：四边不包。切换须保持子树稳定，避免 WebView 重建。
    final immersive = _immersiveChrome;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        unawaited(_handleSystemBack());
      },
      child: Scaffold(
        backgroundColor: _effectiveChromeColor(bootstrap),
        body: SafeArea(
          left: !immersive,
          top: false,
          right: !immersive,
          bottom: !immersive,
          child: SizedBox.expand(child: shell),
        ),
      ),
    );
  }
}
