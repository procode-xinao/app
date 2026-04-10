import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 设备信息服务（系统/机型/版本/包信息）。
class DeviceService {
  final DeviceInfoPlugin _device = DeviceInfoPlugin();

  Future<Map<String, Object?>> getInfo() async {
    final pkg = await PackageInfo.fromPlatform();

    final base = <String, Object?>{
      'appName': pkg.appName,
      'packageName': pkg.packageName,
      'version': pkg.version,
      'buildNumber': pkg.buildNumber,
      'installerStore': pkg.installerStore,
      'platform': _platformName(),
    };

    if (kIsWeb) {
      final info = await _device.webBrowserInfo;
      return {
        ...base,
        'browserName': info.browserName.name,
        'appVersion': info.appVersion,
        'userAgent': info.userAgent,
        'platformRaw': info.platform,
        'vendor': info.vendor,
        'language': info.language,
      };
    }

    if (Platform.isAndroid) {
      final info = await _device.androidInfo;
      return {
        ...base,
        'model': info.model,
        'brand': info.brand,
        'manufacturer': info.manufacturer,
        'device': info.device,
        'product': info.product,
        'androidSdkInt': info.version.sdkInt,
        'androidRelease': info.version.release,
        'androidSecurityPatch': info.version.securityPatch,
        'isPhysicalDevice': info.isPhysicalDevice,
      };
    }

    if (Platform.isIOS) {
      final info = await _device.iosInfo;
      return {
        ...base,
        'name': info.name,
        'systemName': info.systemName,
        'systemVersion': info.systemVersion,
        'model': info.model,
        'modelName': info.modelName,
        'identifierForVendor': info.identifierForVendor,
        'isPhysicalDevice': info.isPhysicalDevice,
      };
    }

    if (Platform.isWindows) {
      final info = await _device.windowsInfo;
      return {
        ...base,
        'computerName': info.computerName,
        'userName': info.userName,
        'numberOfCores': info.numberOfCores,
        'systemMemoryInMegabytes': info.systemMemoryInMegabytes,
        'productName': info.productName,
        'displayVersion': info.displayVersion,
        'buildNumber': info.buildNumber,
        'deviceId': info.deviceId,
      };
    }

    if (Platform.isMacOS) {
      final info = await _device.macOsInfo;
      return {
        ...base,
        'model': info.model,
        'computerName': info.computerName,
        'osRelease': info.osRelease,
        'activeCPUs': info.activeCPUs,
        'memorySize': info.memorySize,
      };
    }

    if (Platform.isLinux) {
      final info = await _device.linuxInfo;
      return {
        ...base,
        'name': info.name,
        'version': info.version,
        'prettyName': info.prettyName,
        'machineId': info.machineId,
        'id': info.id,
      };
    }

    final info = await _device.deviceInfo;
    return {
      ...base,
      'raw': info.data,
    };
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}

