import 'package:url_launcher/url_launcher.dart';

/// 拨号、发短信（走系统界面，依赖 `tel:` / `sms:`）。
class TelephonyService {
  Future<bool> dial(String phone) async {
    final raw = phone.trim();
    if (raw.isEmpty) throw ArgumentError('phone 不能为空');
    final uri = Uri(scheme: 'tel', path: raw);
    if (!await canLaunchUrl(uri)) {
      throw StateError('无法打开拨号: $raw');
    }
    return launchUrl(uri);
  }

  /// [body] 可为空；会经 URI 编码。
  Future<bool> sendSms(String phone, {String? body}) async {
    final raw = phone.trim();
    if (raw.isEmpty) throw ArgumentError('phone 不能为空');
    final uri = Uri(
      scheme: 'sms',
      path: raw,
      queryParameters: (body != null && body.isNotEmpty) ? {'body': body} : null,
    );
    if (!await canLaunchUrl(uri)) {
      throw StateError('无法打开发短信: $raw');
    }
    return launchUrl(uri);
  }
}
