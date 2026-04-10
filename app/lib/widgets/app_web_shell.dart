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
    this.errorFallbackTitle = '页面',
  });

  final String initialUrl;
  final AppJsBridge? bridge;
  final JavaScriptMode javascriptMode;
  final WebNavigationDecision? onNavigationRequest;
  final FutureOr<void> Function(WebViewController controller)? onControllerReady;
  final String errorFallbackTitle;

  @override
  State<AppWebShell> createState() => _AppWebShellState();
}

class _AppWebShellState extends State<AppWebShell> {
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(widget.javascriptMode);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final handler = widget.onNavigationRequest;
            if (handler == null) return NavigationDecision.navigate;
            final shouldNavigate = await handler(request.url);
            return shouldNavigate ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            final bridge = widget.bridge;
            if (bridge != null) {
              unawaited(bridge.injectBootstrap(controller));
            }
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
    return const Center(child: CircularProgressIndicator());
  }
}
