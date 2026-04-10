import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  });

  /// 首次加载的地址（需含协议，如 `https://`）。
  final String initialUrl;

  /// 顶栏标题；为 null 时用 [initialUrl] 的 host，再不行用「浏览器」。
  final String? title;

  final JavaScriptMode javascriptMode;

  final bool showAppBar;

  final bool showProgressBar;

  final bool showNavigationActions;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;
  int _progress = 0;

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    try {
      final host = Uri.parse(widget.initialUrl).host;
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return '浏览器';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(widget.javascriptMode)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (widget.showProgressBar) {
              setState(() => _progress = progress);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    final body = WebViewWidget(controller: _controller);

    if (!widget.showAppBar) {
      return Scaffold(body: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_resolvedTitle),
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
