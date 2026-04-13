import 'dart:async';
import 'dart:convert';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// NFC（NDEF 读取）。需设备支持并已开启 NFC。
class NfcBridgeService {
  Future<Map<String, Object?>> checkAvailability() async {
    final a = await NfcManager.instance.checkAvailability();
    return {'status': a.name};
  }

  /// 启动会话直至读到一条 NDEF 或超时。返回 `records`：每条含 `tnf`、`payloadBase64`。
  Future<Map<String, Object?>> readNdefOnce({int timeoutSec = 30}) async {
    final av = await NfcManager.instance.checkAvailability();
    if (av != NfcAvailability.enabled) {
      throw StateError('NFC 不可用: ${av.name}');
    }
    final timeout = Duration(seconds: timeoutSec.clamp(5, 120));
    final completer = Completer<Map<String, Object?>>();

    Future<void> finishOk(NdefMessage? message) async {
      if (completer.isCompleted) return;
      await NfcManager.instance.stopSession(alertMessageIos: '已读取');
      final records = <Map<String, Object?>>[];
      if (message != null) {
        for (final r in message.records) {
          records.add({
            'tnf': r.typeNameFormat.name,
            'typeBase64': base64Encode(r.type),
            'payloadBase64': base64Encode(r.payload),
          });
        }
      }
      completer.complete({'records': records});
    }

    Future<void> finishErr(Object e) async {
      if (completer.isCompleted) return;
      try {
        await NfcManager.instance.stopSession(errorMessageIos: e.toString());
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        unawaited(finishErr(TimeoutException('NFC 读取超时', timeout)));
      }
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        alertMessageIos: '靠近 NFC 标签',
        onSessionErrorIos: (e) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(StateError('NFC 会话结束: ${e.message}'));
          }
        },
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await finishErr(StateError('标签不支持 NDEF'));
              return;
            }
            final msg = await ndef.read();
            timer.cancel();
            await finishOk(msg);
          } catch (e) {
            timer.cancel();
            await finishErr(e);
          }
        },
      );
    } catch (e) {
      timer.cancel();
      await finishErr(e);
    }

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }
}
