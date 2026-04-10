import 'package:geolocator/geolocator.dart';

/// 获取设备定位（需系统定位权限）。
class LocationService {
  Future<Map<String, Object?>> getCurrentPosition() async {
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

    final p = await Geolocator.getCurrentPosition();
    return {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
      'altitude': p.altitude,
      'heading': p.heading,
      'speed': p.speed,
      'timestamp': p.timestamp.millisecondsSinceEpoch,
    };
  }
}
