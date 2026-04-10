import 'package:flutter/material.dart';

import '../pages/scan_page.dart';

/// 扫码服务：弹出扫码页，返回识别到的文本。
class QrService {
  Future<String> scan({
    required Future<T?> Function<T>(Route<T> route) pushRoute,
  }) async {
    final result = await pushRoute<String>(
      MaterialPageRoute<String>(builder: (_) => const ScanPage()),
    );
    if (result == null || result.isEmpty) {
      throw StateError('扫码已取消');
    }
    return result;
  }
}

