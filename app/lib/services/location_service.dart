import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// 获取设备定位（需系统定位权限）；支持持续上报 [watchPosition]。
class LocationService {
  Future<void> _ensureReady() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw StateError('定位权限被拒绝');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('定位权限被永久拒绝，请在系统设置中开启');
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('定位服务未开启');
    }
  }

  Map<String, Object?> _positionToMap(Position p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'altitude': p.altitude,
        'heading': p.heading,
        'speed': p.speed,
        'timestamp': p.timestamp.millisecondsSinceEpoch,
      };

  Future<Map<String, Object?>> getCurrentPosition() async {
    await _ensureReady();
    final p = await Geolocator.getCurrentPosition();
    return _positionToMap(p);
  }

  /// 持续定位流。Android 下 [androidForegroundService] 为 true 时在后台会显示系统通知（前台服务）。
  Stream<Map<String, Object?>> watchPosition({
    int distanceFilterM = 0,
    int intervalSec = 2,
    bool androidForegroundService = false,
  }) async* {
    await _ensureReady();
    final interval = intervalSec.clamp(1, 3600);
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterM,
        intervalDuration: Duration(seconds: interval),
        foregroundNotificationConfig: androidForegroundService
            ? const ForegroundNotificationConfig(
                notificationText: '应用正在使用定位',
                notificationTitle: '定位服务',
                enableWakeLock: true,
              )
            : null,
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterM,
        activityType: ActivityType.other,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.best);
    }
    await for (final p in Geolocator.getPositionStream(locationSettings: settings)) {
      yield _positionToMap(p);
    }
  }
}
