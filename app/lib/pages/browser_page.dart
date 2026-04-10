import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_js_bridge.dart';

/// 内嵌 WebView 浏览器页。
class BrowserPage extends StatefulWidget {
  const BrowserPage({
    super.key,
    this.initialUrl = 'https://www.baidu.com',
    this.title,
    this.javascriptMode = JavaScriptMode.unrestricted,
    this.showAppBar = true,
    this.showProgressBar = true,
    this.showNavigationActions = true,
    this.enableNativeJsBridge = true,
    this.jsBridge,
  });

  /// 首次加载的地址（需含协议，如 `https://`）。
  final String initialUrl;

  /// 顶栏标题；为 null 时用 [initialUrl] 的 host，再不行用「浏览器」。
  final String? title;

  final JavaScriptMode javascriptMode;

  final bool showAppBar;

  final bool showProgressBar;

  final bool showNavigationActions;

  /// 为 true 时注册 `AppBridge`，页面内可用 `window.App` 调用原生能力。
  final bool enableNativeJsBridge;

  /// 自定义桥（测试或扩展用）；为 null 时由页面自动创建。
  final AppJsBridge? jsBridge;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;
  late final AppJsBridge _bridge;
  int _progress = 0;

  late bool _showAppBar;
  String? _navTitle;
  Color? _navBackgroundColor;
  Color? _navForegroundColor;
  double? _navFontSize;
  FontWeight? _navFontWeight;

  String get _resolvedTitle {
    if (_navTitle != null) return _navTitle!;
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    try {
      final host = Uri.parse(widget.initialUrl).host;
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return '浏览器';
  }

  Color? _tryParseCssColor(String? value) {
    if (value == null) return null;
    var v = value.trim();
    if (v.isEmpty) return null;
    // 支持：#RGB、#RRGGBB、#AARRGGBB
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 3) {
      final r = v[0];
      final g = v[1];
      final b = v[2];
      v = '$r$r$g$g$b$b';
    }
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final parsed = int.tryParse(v, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  void _applyNavigationBarStyle(Map<String, dynamic> style) {
    setState(() {
      if (style.containsKey('title')) {
        final t = style['title'];
        _navTitle = t == null ? null : t.toString();
      }
      if (style.containsKey('backgroundColor')) {
        _navBackgroundColor = _tryParseCssColor(style['backgroundColor']?.toString());
      }
      if (style.containsKey('foregroundColor')) {
        _navForegroundColor = _tryParseCssColor(style['foregroundColor']?.toString());
      }
      if (style.containsKey('fontSize')) {
        final s = style['fontSize'];
        _navFontSize = (s is num) ? s.toDouble() : double.tryParse(s.toString());
      }
      if (style.containsKey('fontWeight')) {
        final w = style['fontWeight'];
        final n = (w is num) ? w.toInt() : int.tryParse(w?.toString() ?? '');
        if (n != null) {
          // 支持 100~900，常见 400/500/600/700
          final clamped = n.clamp(100, 900);
          _navFontWeight = FontWeight.values[(clamped ~/ 100) - 1];
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _showAppBar = widget.showAppBar;
    _bridge = widget.jsBridge ??
        AppJsBridge(
          showSnackBar: _showSnackBar,
          isMounted: () => mounted,
          pushRoute: <T>(Route<T> route) => Navigator.of(context).push(route),
          setNavigationBarStyle: _applyNavigationBarStyle,
          setNavigationBarVisible: (visible) => setState(() => _showAppBar = visible),
          setNavigationBarTitle: (title) => setState(() => _navTitle = title),
        );

    _controller = WebViewController()
      ..setJavaScriptMode(widget.javascriptMode)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (widget.showProgressBar) {
              setState(() => _progress = progress);
            }
          },
          onPageFinished: (_) {
            if (widget.enableNativeJsBridge) {
              unawaited(_bridge.injectBootstrap(_controller));
            }
          },
        ),
      );

    if (widget.enableNativeJsBridge) {
      _bridge.registerChannel(_controller);
    }

    _controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = WebViewWidget(controller: _controller);

    if (!_showAppBar) {
      return Scaffold(body: body);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navBackgroundColor,
        foregroundColor: _navForegroundColor,
        title: Text(
          _resolvedTitle,
          style: TextStyle(
            color: _navForegroundColor,
            fontSize: _navFontSize,
            fontWeight: _navFontWeight,
          ),
        ),
        bottom: widget.showProgressBar && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                ),
              )
            : null,
        actions: widget.showNavigationActions
            ? [
                IconButton(
                  tooltip: '后退',
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: '前进',
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      await _controller.goForward();
                    }
                  },
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _controller.reload,
                  icon: const Icon(Icons.refresh),
                ),
              ]
            : null,
      ),
      body: body,
    );
  }
}
