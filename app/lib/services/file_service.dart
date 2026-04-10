import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 文件管理服务（基于应用沙盒 + 文件选择器）。
class FileService {
  /// 选择一个文件并返回基础信息。
  ///
  /// 返回：
  /// `{ name, path, size }`
  Future<Map<String, Object?>> pickFile() async {
    final result = await FilePicker.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) {
      throw StateError('已取消选择文件');
    }
    final f = result.files.first;
    final path = f.path;
    if (path == null || path.isEmpty) {
      throw StateError('无法获取文件路径（可能是 Web 平台或系统限制）');
    }
    return {
      'name': f.name,
      'path': path,
      'size': f.size,
    };
  }

  Future<String> readText(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('文件不存在: $path');
    return file.readAsString();
  }

  Future<void> writeText(String path, String text) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<void> delete(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.notFound) return;
    if (entity == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
      return;
    }
    await File(path).delete();
  }

  Future<List<Map<String, Object?>>> listDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) throw StateError('目录不存在: $path');
    final out = <Map<String, Object?>>[];
    await for (final entity in dir.list(followLinks: false)) {
      final stat = await entity.stat();
      out.add({
        'path': entity.path,
        'type': stat.type.toString().split('.').last,
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
      });
    }
    return out;
  }

  /// 返回应用文档目录（推荐 JS 写入的默认根目录）。
  Future<Map<String, Object?>> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return {'documents': dir.path};
  }
}

