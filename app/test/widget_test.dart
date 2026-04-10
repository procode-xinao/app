import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';
import 'package:app/pages/browser_page.dart';

void main() {
  test('BrowserPage 默认地址', () {
    const page = BrowserPage();
    expect(page.initialUrl, 'https://www.baidu.com');
  });

  test('MyApp 可实例化', () {
    expect(const MyApp(), isNotNull);
  });
}
