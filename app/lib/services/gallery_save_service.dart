import 'dart:convert';
import 'dart:io';

import 'package:gal/gal.dart';

/// 保存图片到系统相册（需相册写入权限）。
class GallerySaveService {
  Future<bool> saveImageFromPath(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      throw StateError('文件不存在: $path');
    }
    final ok = await Gal.requestAccess(toAlbum: false);
    if (!ok) throw StateError('相册权限被拒绝');
    await Gal.putImage(path);
    return true;
  }

  Future<bool> saveImageFromBase64(String base64, {String name = 'image'}) async {
    final bytes = base64Decode(base64.replaceAll(RegExp(r'\s'), ''));
    final ok = await Gal.requestAccess(toAlbum: false);
    if (!ok) throw StateError('相册权限被拒绝');
    await Gal.putImageBytes(bytes, name: name);
    return true;
  }
}
