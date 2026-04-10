import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_bootstrap_service.dart';
import '../services/push_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_web_shell.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AppBootstrapService _service = AppBootstrapService();
  final StorageService _storage = StorageService();
  AppBootstrapResult? _bootstrap;
  String? _error;
  bool _jumped = false;
  String? _validatedToken;
  bool _tokenValid = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final bootstrap = await _service.load();
      await PushService.ensureInitialized(appKey: bootstrap.app.jpushAppKey);
      final token = await _storage.getString('access_token');
      final normalized = token?.trim();
      final valid = normalized != null && normalized.isNotEmpty
          ? await _service.validateToken(
              serverBaseUrl: bootstrap.serverBaseUrl,
              token: normalized,
            )
          : false;
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _validatedToken = valid ? normalized : null;
        _tokenValid = valid;
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted || _jumped) return;
      _jumped = true;
      if (_tokenValid) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              bootstrap: bootstrap,
              initialAccessToken: _validatedToken,
            ),
          ),
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginPage(bootstrap: bootstrap)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final splashUrl = bootstrap.app.splashUrl.trim().isNotEmpty
        ? _service.resolveToAbsoluteUrl(bootstrap.serverBaseUrl, bootstrap.app.splashUrl)
        : bootstrap.homeUrl;
    return Scaffold(
      body: AppWebShell(
        initialUrl: splashUrl,
      ),
    );
  }
}
