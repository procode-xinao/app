import 'package:local_auth/local_auth.dart';

/// 生物识别服务（指纹/FaceID/Windows Hello 等）。
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    final can = await _auth.canCheckBiometrics;
    return can || await _auth.isDeviceSupported();
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return _auth.getAvailableBiometrics();
  }

  Future<bool> authenticate({required String reason, bool biometricOnly = false}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('reason 不能为空');
    }
    return _auth.authenticate(
      localizedReason: reason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: true,
    );
  }
}

