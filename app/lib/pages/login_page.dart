import 'package:flutter/material.dart';

import '../services/app_bootstrap_service.dart';
import '../services/app_js_bridge.dart';
import '../services/storage_service.dart';
import '../widgets/app_web_shell.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.bootstrap,
  });

  final AppBootstrapResult bootstrap;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final StorageService _storage = StorageService();
  late final List<String> _homeUrls;
  late final AppJsBridge _bridge;
  bool _showAppBar = true;
  String? _title;
  Color? _navBg;
  Color? _navFg;
  double? _navFontSize;
  FontWeight? _navFontWeight;

  @override
  void initState() {
    super.initState();
    _title = '登录';
    _homeUrls = widget.bootstrap.navigations
        .map((e) => AppBootstrapService().resolveToAbsoluteUrl(widget.bootstrap.serverBaseUrl, e.url))
        .toList();
    _navBg = _parseColor(widget.bootstrap.app.topNavigationBackgroundColor);
    _navFg = _parseColor(widget.bootstrap.app.topFontColor);
    _bridge = AppJsBridge(
      showSnackBar: _showSnackBar,
      isMounted: () => mounted,
      pushRoute: <T>(Route<T> route) => Navigator.of(context).push(route),
      setNavigationBarVisible: (visible) => setState(() => _showAppBar = visible),
      setNavigationBarTitle: (title) => setState(() => _title = title),
      setNavigationBarStyle: _applyNavigationBarStyle,
      goHome: _goHome,
    );
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    var v = value.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 3) v = '${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}';
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

  Future<bool> _handleNavigation(String url) async {
    if (_homeUrls.contains(url)) {
      final token = await _storage.getString('access_token');
      if (!mounted) return false;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            bootstrap: widget.bootstrap,
            initialAccessToken: token?.trim().isNotEmpty == true ? token : null,
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _goHome() async {
    final token = await _storage.getString('access_token');
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          bootstrap: widget.bootstrap,
          initialAccessToken: token?.trim().isNotEmpty == true ? token : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginUrl = widget.bootstrap.app.loginUrl.trim().isNotEmpty
        ? AppBootstrapService().resolveToAbsoluteUrl(
            widget.bootstrap.serverBaseUrl,
            widget.bootstrap.app.loginUrl,
          )
        : widget.bootstrap.homeUrl;
    return Scaffold(
      appBar: _showAppBar
          ? AppBar(
              centerTitle: true,
              automaticallyImplyLeading: false,
              backgroundColor: _navBg,
              foregroundColor: _navFg,
              title: Text(
                _title ?? '登录',
                style: TextStyle(
                  color: _navFg,
                  fontSize: _navFontSize,
                  fontWeight: _navFontWeight,
                ),
              ),
            )
          : null,
      body: AppWebShell(
        initialUrl: loginUrl,
        bridge: _bridge,
        onNavigationRequest: _handleNavigation,
      ),
    );
  }
}
