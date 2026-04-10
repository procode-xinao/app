import 'package:url_launcher/url_launcher.dart';

/// 使用系统能力打开链接或其它 App（mailto、tel、https、自定义 scheme 等）。
class LauncherService {
  Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw ArgumentError('无效的 URL: $url');
    }
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      throw StateError('无法打开: $url');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
