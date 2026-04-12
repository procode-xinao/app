import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_branding.dart';
import '../utils/hex_color.dart';

const String kExternalServerUrl = String.fromEnvironment(
  'APP_EXTERNAL_SERVER_URL',
  defaultValue: 'http://web.arsoft.com.cn:6002',
);
const String kInternalServerUrl = String.fromEnvironment(
  'APP_INTERNAL_SERVER_URL',
  defaultValue: 'http://web.arsoft.com.cn:6002',
);
const String kAppCode = String.fromEnvironment(
  'APP_CODE',
  defaultValue: 'code',
);

/// `/v1/app` 拉取结果：必填 `url`、`is_enable`；可选 `jpush_app_key`、`top_background_color`。
class AppBootstrapResult {
  AppBootstrapResult({
    required this.serverBaseUrl,
    required this.entryUrl,
    required this.jpushAppKey,
    required this.topBackgroundColor,
  });

  final String serverBaseUrl;
  /// 由响应中的 `url` 与 [serverBaseUrl] 解析得到的 H5 入口。
  final String entryUrl;
  final String jpushAppKey;
  /// 非全屏时状态栏/安全区衬色；来自 `top_background_color` 或 [kTopBackgroundColorDefine]。
  final Color topBackgroundColor;
}

class AppBootstrapService {
  Future<AppBootstrapResult> load() async {
    final candidates = <String>[
      kExternalServerUrl.trim(),
      kInternalServerUrl.trim(),
    ].where((e) => e.isNotEmpty).toList();

    Object? lastError;
    for (var i = 0; i < candidates.length; i++) {
      final baseUrl = candidates[i];
      if (i > 0 && baseUrl == candidates[i - 1]) continue;
      try {
        final uri = Uri.parse(baseUrl).resolve('/api/${Uri.encodeComponent(kAppCode)}/v1/app');
        final data = await _getJsonObject(uri);
        if (data['is_enable'] != true) throw Exception('app disabled');

        final raw = data['url'];
        final pathOrUrl = raw == null ? '' : raw.toString().trim();
        if (pathOrUrl.isEmpty) throw Exception('missing url');

        return AppBootstrapResult(
          serverBaseUrl: baseUrl,
          entryUrl: _resolveToAbsoluteUrl(baseUrl, pathOrUrl),
          jpushAppKey: (data['jpush_app_key'] ?? '').toString(),
          topBackgroundColor: _resolveTopBackgroundColor(data),
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('bootstrap failed');
  }

  String resolveToAbsoluteUrl(String serverBaseUrl, String target) =>
      _resolveToAbsoluteUrl(serverBaseUrl, target);

  Future<bool> validateToken({
    required String serverBaseUrl,
    required String token,
  }) async {
    if (token.trim().isEmpty) return false;
    final uri = Uri.parse(serverBaseUrl).resolve('/api/${Uri.encodeComponent(kAppCode)}/v1/user');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token.trim()}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _getJsonObject(Uri uri) async {
    final data = await _getJson(uri);
    if (data is Map<String, dynamic>) return data;
    throw Exception('json object expected');
  }

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final raw = await response.transform(utf8.decoder).join();
      return jsonDecode(raw);
    } finally {
      client.close(force: true);
    }
  }

  String _resolveToAbsoluteUrl(String baseUrl, String target) {
    final direct = Uri.tryParse(target);
    if (direct != null && direct.hasScheme) return target;
    return Uri.parse(baseUrl).resolve(target).toString();
  }

  Color _resolveTopBackgroundColor(Map<String, dynamic> data) {
    final fromApi = parseHexColor(data['top_background_color']?.toString());
    if (fromApi != null) return fromApi;
    final fromDefine = parseHexColor(kTopBackgroundColorDefine);
    return fromDefine ?? const Color(0xFF000000);
  }
}
