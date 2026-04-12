import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_js_bridge.dart';

typedef WebNavigationDecision = FutureOr<bool> Function(String url);

class AppWebShell extends StatefulWidget {
  const AppWebShell({
    super.key,
    required this.initialUrl,
    this.bridge,
    this.javascriptMode = JavaScriptMode.unrestricted,
    this.onNavigationRequest,
    this.onControllerReady,
    this.onPageFinished,
    this.errorFallbackTitle = '页面',
    this.nativeLikeLockdown = true,
    this.showLoadingIndicator = true,
    this.chromeBackgroundColor,
  });

  final String initialUrl;
  final AppJsBridge? bridge;
  final JavaScriptMode javascriptMode;
  final WebNavigationDecision? onNavigationRequest;
  final FutureOr<void> Function(WebViewController controller)? onControllerReady;
  /// 主文档加载完成（含子资源由 WebView 决定何时触发）。
  final void Function(String url)? onPageFinished;
  final String errorFallbackTitle;
  final bool nativeLikeLockdown;
  /// WebView 未就绪时是否显示转圈；启动欢迎页可设为 false。
  final bool showLoadingIndicator;
  /// WebView 底层背景色（与壳衬色一致可减少闪白/与状态栏衔接）。
  final Color? chromeBackgroundColor;

  @override
  State<AppWebShell> createState() => _AppWebShellState();
}

class _AppWebShellState extends State<AppWebShell> {
  WebViewController? _controller;
  String? _error;
  static const String _nativeLikeScript = r'''
(function () {
  if (window.__appNativeLikeInstalled) return;
  window.__appNativeLikeInstalled = true;

  // 禁止长按菜单、文本选中、图片拖拽、复制粘贴等浏览器交互
  const style = document.createElement('style');
  style.innerHTML = `
    * {
      -webkit-touch-callout: none !important;
      -webkit-user-select: none !important;
      user-select: none !important;
      -webkit-tap-highlight-color: transparent !important;
    }
    html {
      height: 100%;
      overscroll-behavior: none !important;
      overscroll-behavior-y: none !important;
    }
    body {
      min-height: 100%;
      overscroll-behavior: none !important;
      overscroll-behavior-y: none !important;
    }
  `;
  document.head.appendChild(style);

  ['contextmenu', 'selectstart', 'dragstart', 'copy', 'cut', 'paste'].forEach(function (evt) {
    document.addEventListener(evt, function (e) { e.preventDefault(); }, { passive: false });
  });

  // 阻止页面用 window.open 打开新窗口，统一当前页跳转
  window.open = function (url) {
    if (typeof url === 'string' && url) {
      location.href = url;
    }
    return null;
  };

  // 注入 viewport，限制缩放，减少“浏览器感”
  var viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement('meta');
    viewport.setAttribute('name', 'viewport');
    document.head.appendChild(viewport);
  }
  viewport.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no');
})();
''';

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(widget.javascriptMode);
      // 禁止双指捏合等手势缩放（与 viewport user-scalable=no 叠加）
      await controller.enableZoom(false);
      await controller.setOverScrollMode(WebViewOverScrollMode.never);
      final bg = widget.chromeBackgroundColor;
      if (bg != null) {
        await controller.setBackgroundColor(bg);
      }
      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final handler = widget.onNavigationRequest;
            if (handler == null) return NavigationDecision.navigate;
            final shouldNavigate = await handler(request.url);
            return shouldNavigate ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageFinished: (String url) {
            if (widget.nativeLikeLockdown) {
              unawaited(controller.runJavaScript(_nativeLikeScript));
            }
            final bridge = widget.bridge;
            if (bridge != null) {
              unawaited(bridge.injectBootstrap(controller));
            }
            widget.onPageFinished?.call(url);
          },
        ),
      );
      final bridge = widget.bridge;
      if (bridge != null) {
        bridge.registerChannel(controller);
      }
      await controller.loadRequest(Uri.parse(widget.initialUrl));
      if (!mounted) return;
      setState(() => _controller = controller);
      await widget.onControllerReady?.call(controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return WebViewWidget(controller: controller);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '当前运行环境不支持 WebView。\n'
            '请在 Android/iOS 真机或模拟器运行。\n\n'
            '$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (widget.showLoadingIndicator) {
      return const Center(child: CircularProgressIndicator());
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SizedBox.expand(),
    );
  }
}
