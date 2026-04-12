import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

String _describeLocalAuth(LocalAuthException e) {
  final extra = e.description?.trim();
  return extra != null && extra.isNotEmpty
      ? '生物识别失败（${e.code.name}）：$extra'
      : '生物识别失败（${e.code.name}）';
}

/// 生物识别服务（指纹/Face ID/Windows Hello 等）。
///
/// 从 WebView 经 [AppJsBridge] 调用时，若在平台回调里**同步**弹出系统识别界面，
/// 部分机型会报 [LocalAuthExceptionCode.uiUnavailable]（无可用 Activity）。
/// 因此 [authenticate] 将实际调用推迟到 **下一帧** 再执行。
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
    final completer = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final ok = await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: biometricOnly,
          // WebView 场景下 sticky 与敏感交易二次确认易与窗口层级冲突，改为更稳妥的默认
          persistAcrossBackgrounding: false,
          sensitiveTransaction: false,
        );
        if (!completer.isCompleted) completer.complete(ok);
      } on LocalAuthException catch (e) {
        if (!completer.isCompleted) completer.completeError(Exception(_describeLocalAuth(e)));
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
