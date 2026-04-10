import 'package:flutter/material.dart';
import 'splash_page.dart';

/// 兼容旧入口：统一转到新的启动页流程。
class BrowserPage extends StatefulWidget {
  const BrowserPage({
    super.key,
  });

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
