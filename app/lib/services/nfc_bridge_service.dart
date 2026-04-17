import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
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

  /// 读取公交/门禁等非 NDEF 卡可公开访问的基础信息（如 UID、技术类型）。
  ///
  /// 说明：
  /// - 仅返回公开层信息，不尝试私有区读写或任何破解行为。
  /// - 结果字段会因卡片与平台差异而不同。
  Future<Map<String, Object?>> readTransitPublicOnce({int timeoutSec = 20}) async {
    final av = await NfcManager.instance.checkAvailability();
    if (av != NfcAvailability.enabled) {
      throw StateError('NFC 不可用: ${av.name}');
    }
    final timeout = Duration(seconds: timeoutSec.clamp(5, 60));
    final completer = Completer<Map<String, Object?>>();

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
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: '靠近公交卡或门禁卡',
        onSessionErrorIos: (e) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(StateError('NFC 会话结束: ${e.message}'));
          }
        },
        onDiscovered: (tag) async {
          try {
            timer.cancel();
            final ndef = Ndef.from(tag);
            final isAndroid = defaultTargetPlatform == TargetPlatform.android;
            final isIos = defaultTargetPlatform == TargetPlatform.iOS;

            final isoDep = isAndroid ? IsoDepAndroid.from(tag) : null;
            final nfcA = isAndroid ? NfcAAndroid.from(tag) : null;
            final nfcB = isAndroid ? NfcBAndroid.from(tag) : null;
            final nfcF = isAndroid ? NfcFAndroid.from(tag) : null;
            final nfcV = isAndroid ? NfcVAndroid.from(tag) : null;
            final mifareClassic = isAndroid ? MifareClassicAndroid.from(tag) : null;
            final mifareUltralight = isAndroid ? MifareUltralightAndroid.from(tag) : null;
            final androidTag = isAndroid ? NfcTagAndroid.from(tag) : null;

            final iso7816Ios = isIos ? Iso7816Ios.from(tag) : null;
            final miFareIos = isIos ? MiFareIos.from(tag) : null;
            final feliCaIos = isIos ? FeliCaIos.from(tag) : null;
            final iso15693Ios = isIos ? Iso15693Ios.from(tag) : null;
            final uidBytes = _extractIdentifier(
              androidTag: androidTag,
              nfcA: nfcA,
              miFareIos: miFareIos,
              iso7816Ios: iso7816Ios,
              feliCaIos: feliCaIos,
              iso15693Ios: iso15693Ios,
            );
            final techList = <String>[
              if (ndef != null) 'ndef',
              if (isoDep != null) 'isodep',
              if (nfcA != null) 'nfca',
              if (nfcB != null) 'nfcb',
              if (nfcF != null) 'nfcf',
              if (nfcV != null) 'nfcv',
              if (mifareClassic != null) 'mifareclassic',
              if (mifareUltralight != null) 'mifareultralight',
              if (iso7816Ios != null) 'iso7816',
              if (miFareIos != null) 'mifare',
              if (feliCaIos != null) 'felica',
              if (iso15693Ios != null) 'iso15693',
            ];
            final payload = <String, Object?>{
              'uidHex': uidBytes == null ? null : _toHex(uidBytes),
              'techList': androidTag?.techList ?? techList,
              'isNdef': ndef != null,
              if (isoDep != null)
                'isoDep': {
                  'hiLayerResponseBase64': _encodeBytesOrNull(isoDep.hiLayerResponse),
                  'historicalBytesBase64': _encodeBytesOrNull(isoDep.historicalBytes),
                },
              if (nfcA != null)
                'nfcA': {
                  'atqaHex': _toHexOrNull(nfcA.atqa),
                  'sak': nfcA.sak,
                },
              if (nfcB != null)
                'nfcB': {
                  'applicationDataBase64': _encodeBytesOrNull(nfcB.applicationData),
                  'protocolInfoBase64': _encodeBytesOrNull(nfcB.protocolInfo),
                },
            };
            await NfcManager.instance.stopSession(alertMessageIos: '已读取');
            if (!completer.isCompleted) {
              completer.complete(payload);
            }
          } catch (e) {
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

  List<int>? _extractIdentifier({
    NfcTagAndroid? androidTag,
    NfcAAndroid? nfcA,
    MiFareIos? miFareIos,
    Iso7816Ios? iso7816Ios,
    FeliCaIos? feliCaIos,
    Iso15693Ios? iso15693Ios,
  }) {
    final candidates = <Object?>[
      androidTag?.id,
      miFareIos?.identifier,
      iso7816Ios?.identifier,
      feliCaIos?.currentIDm,
      iso15693Ios?.identifier,
    ];
    for (final c in candidates) {
      final bytes = _toIntListOrNull(c);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    return null;
  }

  String? _toHexOrNull(Object? bytes) {
    final list = _toIntListOrNull(bytes);
    if (list == null || list.isEmpty) return null;
    return _toHex(list);
  }

  String? _encodeBytesOrNull(Object? bytes) {
    final list = _toIntListOrNull(bytes);
    if (list == null || list.isEmpty) return null;
    return base64Encode(list);
  }

  List<int>? _toIntListOrNull(Object? value) {
    if (value is List) {
      final out = <int>[];
      for (final e in value) {
        if (e is int) out.add(e & 0xFF);
      }
      return out;
    }
    return null;
  }

  String _toHex(List<int> bytes) =>
      bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
}
