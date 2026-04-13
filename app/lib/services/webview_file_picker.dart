import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// 为 Android WebView 注册 `<input type="file">` 选择回调；iOS WKWebView 由系统处理。
Future<void> configureWebViewFileSelector(WebViewController controller) async {
  if (kIsWeb || !Platform.isAndroid) return;
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) return;
  await platform.setOnShowFileSelector(_androidPickFiles);
}

Future<List<String>> _androidPickFiles(FileSelectorParams params) async {
  if (params.mode == FileSelectorMode.save) {
    return [];
  }
  final allowMultiple = params.mode == FileSelectorMode.openMultiple;
  final types = params.acceptTypes;
  var ft = FileType.any;
  if (types.isNotEmpty) {
    final allImage = types.every(
      (t) => t.toLowerCase().startsWith('image/') || t == 'image/*',
    );
    final allVideo = types.every(
      (t) => t.toLowerCase().startsWith('video/') || t == 'video/*',
    );
    if (allImage) {
      ft = FileType.image;
    } else if (allVideo) {
      ft = FileType.video;
    }
  }

  if (params.isCaptureEnabled && ft == FileType.image) {
    final xFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xFile == null) return [];
    return [xFile.path];
  }

  final result = await FilePicker.pickFiles(
    allowMultiple: allowMultiple,
    type: ft,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return [];
  return result.files.map((f) => f.path).whereType<String>().toList();
}
