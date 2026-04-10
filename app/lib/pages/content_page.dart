import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_js_bridge.dart';
import '../widgets/app_web_shell.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({
    super.key,
    required this.initialUrl,
    required this.title,
    this.topBackgroundColor,
    this.topFontColor,
    this.bridgeEnabled = true,
  });

  final String initialUrl;
  final String title;
  final Color? topBackgroundColor;
  final Color? topFontColor;
  final bool bridgeEnabled;

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  late final AppJsBridge _bridge;
  String? _title;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _bridge = AppJsBridge(
      showSnackBar: _showSnackBar,
      isMounted: () => mounted,
      pushRoute: <T>(Route<T> route) => Navigator.of(context).push(route),
      setNavigationBarTitle: (title) => setState(() => _title = title),
      setNavigationBarVisible: (visible) => setState(() => _showAppBar = visible),
    );
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showAppBar
          ? AppBar(
              centerTitle: true,
              backgroundColor: widget.topBackgroundColor,
              foregroundColor: widget.topFontColor,
              title: Text(_title ?? widget.title),
              leading: IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
            )
          : null,
      body: AppWebShell(
        initialUrl: widget.initialUrl,
        javascriptMode: JavaScriptMode.unrestricted,
        bridge: widget.bridgeEnabled ? _bridge : null,
      ),
    );
  }
}
