import 'package:share_plus/share_plus.dart';

/// 系统分享面板。
class ShareService {
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  Future<void> shareUri(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw ArgumentError('无效的 URL: $url');
    await SharePlus.instance.share(ShareParams(uri: uri));
  }
}
