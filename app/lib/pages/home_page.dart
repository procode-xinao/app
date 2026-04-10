import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_bootstrap_service.dart';
import '../services/app_js_bridge.dart';
import '../widgets/app_web_shell.dart';
import 'content_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.bootstrap,
    this.initialAccessToken,
  });

  final AppBootstrapResult bootstrap;
  final String? initialAccessToken;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WebViewController? _controller;
  late final AppJsBridge _bridge;
  late final List<String> _tabUrls;

  late int _currentIndex;
  bool _showScan = true;
  bool _showAppBar = true;
  String? _title;
  bool _titleOverriddenByWeb = false;
  Color? _navBg;
  Color? _navFg;
  double? _navFontSize;
  FontWeight? _navFontWeight;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.bootstrap.homeIndex;
    _title = _defaultTitleForIndex(_currentIndex);
    _tabUrls = widget.bootstrap.navigations
        .map((e) => AppBootstrapService().resolveToAbsoluteUrl(widget.bootstrap.serverBaseUrl, e.url))
        .toList();
    _navBg = _parseColor(widget.bootstrap.app.topNavigationBackgroundColor);
    _navFg = _parseColor(widget.bootstrap.app.topFontColor);

    _bridge = AppJsBridge(
      showSnackBar: _showSnackBar,
      isMounted: () => mounted,
      pushRoute: <T>(Route<T> route) => Navigator.of(context).push(route),
      setNavigationBarStyle: _applyNavigationBarStyle,
      setNavigationBarVisible: (visible) => setState(() => _showAppBar = visible),
      setNavigationBarTitle: (title) => setState(() {
        _titleOverriddenByWeb = true;
        _title = title;
      }),
      setNavigationBarButtons: ({back, scan}) {
        if (scan != null) setState(() => _showScan = scan);
      },
    );
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

  String _defaultTitleForIndex(int index) {
    if (index >= 0 && index < widget.bootstrap.navigations.length) {
      final name = widget.bootstrap.navigations[index].name.trim();
      if (name.isNotEmpty) return name;
    }
    return widget.bootstrap.app.name;
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    var v = value.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 3) {
      v = '${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}';
    }
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }

  void _applyNavigationBarStyle(Map<String, dynamic> style) {
    setState(() {
      final title = style['title'];
      if (title != null) _title = title.toString();
      final bg = style['backgroundColor']?.toString();
      final fg = style['foregroundColor']?.toString();
      final fs = style['fontSize'];
      final fw = style['fontWeight'];
      if (bg != null) _navBg = _parseColor(bg);
      if (fg != null) _navFg = _parseColor(fg);
      if (fs is num) _navFontSize = fs.toDouble();
      if (fw is num) {
        final clamped = fw.toInt().clamp(100, 900);
        _navFontWeight = FontWeight.values[(clamped ~/ 100) - 1];
      }
    });
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _onScan() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;
    final uri = Uri.tryParse(result.trim());
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await controller.loadRequest(uri);
    } else {
      _showSnackBar(result.trim());
    }
  }

  Future<void> _onBottomTap(int index) async {
    if (index < 0 || index >= _tabUrls.length) return;
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _currentIndex = index;
      _titleOverriddenByWeb = false;
      _title = _defaultTitleForIndex(index);
    });
    await controller.loadRequest(Uri.parse(_tabUrls[index]));
  }

  Future<bool> _handleNavigation(String url) async {
    final idx = _tabUrls.indexOf(url);
    if (idx >= 0) {
      if (idx != _currentIndex) {
        setState(() {
          _currentIndex = idx;
          if (!_titleOverriddenByWeb) {
            _title = _defaultTitleForIndex(idx);
          }
        });
      } else if (!_titleOverriddenByWeb) {
        setState(() => _title = _defaultTitleForIndex(idx));
      }
      return true;
    }
    if (!mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContentPage(
          initialUrl: url,
          title: _title ?? widget.bootstrap.app.name,
          topBackgroundColor: _navBg,
          topFontColor: _navFg,
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.bootstrap.app;
    final bottomBg = _parseColor(app.bottomNavigationBackgroundColor);
    final bottomNormal = _parseColor(app.bottomFontColor);
    final bottomActive = _parseColor(app.bottomActiveFontColor);

    return Scaffold(
      appBar: _showAppBar
          ? AppBar(
              centerTitle: true,
              backgroundColor: _navBg,
              foregroundColor: _navFg,
              title: Text(
                _title ?? _defaultTitleForIndex(_currentIndex),
                style: TextStyle(
                  color: _navFg,
                  fontSize: _navFontSize,
                  fontWeight: _navFontWeight,
                ),
              ),
              automaticallyImplyLeading: false,
              actions: _showScan
                  ? [
                      IconButton(
                        tooltip: '扫码',
                        onPressed: _onScan,
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ]
                  : null,
            )
          : null,
      body: AppWebShell(
        initialUrl: widget.bootstrap.homeUrl,
        bridge: _bridge,
        onControllerReady: (c) async {
          _controller = c;
          final token = widget.initialAccessToken;
          if (token != null && token.trim().isNotEmpty) {
            await _setAccessTokenToWebStorage(c, token.trim());
          }
        },
        onNavigationRequest: _handleNavigation,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, widget.bootstrap.navigations.length - 1),
        type: BottomNavigationBarType.fixed,
        backgroundColor: bottomBg,
        unselectedItemColor: bottomNormal,
        selectedItemColor: bottomActive,
        unselectedFontSize: app.bottomFontSize ?? 12,
        selectedFontSize: app.bottomActiveFontSize ?? 14,
        items: widget.bootstrap.navigations
            .map(
              (e) => BottomNavigationBarItem(
                icon: e.icon.trim().isNotEmpty
                    ? Image.network(
                        e.icon,
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(Icons.circle_outlined),
                      )
                    : const Icon(Icons.circle_outlined),
                activeIcon: e.icon.trim().isNotEmpty
                    ? Image.network(
                        e.icon,
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(Icons.circle),
                      )
                    : const Icon(Icons.circle),
                label: e.name,
              ),
            )
            .toList(),
        onTap: _onBottomTap,
      ),
    );
  }
}
