import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙：适配器状态与短时扫描（不维持连接）。
class BluetoothBridgeService {
  Future<Map<String, Object?>> getStatus() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return {'supported': false, 'adapterState': 'unsupported'};
    }
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      return {'supported': false, 'adapterState': 'unsupported'};
    }
    final state = FlutterBluePlus.adapterStateNow;
    return {
      'supported': true,
      'adapterState': state.toString().split('.').last,
    };
  }

  /// 扫描 [timeoutSec] 秒（1–30），返回发现的广播设备列表。
  Future<List<Map<String, Object?>>> scan({int timeoutSec = 8}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw UnsupportedError('蓝牙扫描仅支持 Android / iOS');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('设备不支持蓝牙');
    }
    final t = timeoutSec.clamp(1, 30);
    await FlutterBluePlus.startScan(timeout: Duration(seconds: t));
    await Future<void>.delayed(Duration(seconds: t));
    await FlutterBluePlus.stopScan();
    final out = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final r in FlutterBluePlus.lastScanResults) {
      final id = r.device.remoteId.str;
      if (seen.contains(id)) continue;
      seen.add(id);
      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : r.device.platformName;
      out.add({
        'id': id,
        'name': name,
        'rssi': r.rssi,
      });
    }
    return out;
  }
}
