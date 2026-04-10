import 'package:flutter/material.dart';

import 'app_branding.dart';
import 'pages/browser_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppDisplayName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BrowserPage(
        initialUrl: 'https://www.baidu.com',
        title: '百度',
      ),
    );
  }
}
