import 'dart:convert';
import 'dart:io';

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

class AppBootstrapResult {
  AppBootstrapResult({
    required this.serverBaseUrl,
    required this.app,
    required this.navigations,
    required this.homeUrl,
    required this.homeIndex,
  });

  final String serverBaseUrl;
  final AppConfig app;
  final List<AppNavigationItem> navigations;
  final String homeUrl;
  final int homeIndex;
}

class AppConfig {
  AppConfig({
    required this.name,
    required this.splashUrl,
    required this.defaultNavigationId,
    required this.bottomNavigationBackgroundColor,
    required this.bottomFontColor,
    required this.bottomActiveFontColor,
    required this.bottomFontSize,
    required this.bottomActiveFontSize,
    required this.topNavigationBackgroundColor,
    required this.topFontColor,
    required this.loginUrl,
    required this.jpushAppKey,
    required this.isEnable,
  });

  final String name;
  final String splashUrl;
  final int? defaultNavigationId;
  final String? bottomNavigationBackgroundColor;
  final String? bottomFontColor;
  final String? bottomActiveFontColor;
  final double? bottomFontSize;
  final double? bottomActiveFontSize;
  final String? topNavigationBackgroundColor;
  final String? topFontColor;
  final String loginUrl;
  final String jpushAppKey;
  final bool isEnable;
}

class AppNavigationItem {
  AppNavigationItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.order,
    required this.isEnable,
  });

  final int id;
  final String name;
  final String icon;
  final String url;
  final int order;
  final bool isEnable;
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
        final app = await _fetchApp(baseUrl);
        if (!app.isEnable) throw Exception('app disabled');
        final navs = await _fetchNavigations(baseUrl);
        final homeIndex = app.defaultNavigationId == null
            ? -1
            : navs.indexWhere((e) => e.id == app.defaultNavigationId);
        final homeUrl = (homeIndex >= 0 && homeIndex < navs.length)
            ? _resolveToAbsoluteUrl(baseUrl, navs[homeIndex].url)
            : navs.isNotEmpty
            ? _resolveToAbsoluteUrl(baseUrl, navs.first.url)
            : baseUrl;
        return AppBootstrapResult(
          serverBaseUrl: baseUrl,
          app: app,
          navigations: navs,
          homeUrl: homeUrl,
          homeIndex: homeIndex < 0 ? 0 : homeIndex,
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

  Future<AppConfig> _fetchApp(String baseUrl) async {
    final uri = Uri.parse(baseUrl).resolve('/api/${Uri.encodeComponent(kAppCode)}/v1/app');
    final data = await _getJsonObject(uri);
    return AppConfig(
      name: (data['name'] ?? data['f_name'] ?? '').toString(),
      splashUrl: (data['url'] ?? data['f_url'] ?? '').toString(),
      defaultNavigationId: _toIntOrNull(
        data['app_navigation_id'] ?? data['default_navigation_id'] ?? data['f_app_navigation_id'],
      ),
      bottomNavigationBackgroundColor: _readString(
        data,
        const ['bottom_navigation_background_color', 'f_bottom_navigation_background_color'],
      ),
      bottomFontColor: _readString(data, const ['bottom_font_color', 'f_bottom_font_color']),
      bottomActiveFontColor: _readString(
        data,
        const ['bottom_active_font_color', 'f_bottom_active_font_color'],
      ),
      bottomFontSize: _toDoubleOrNull(data['bottom_font_size'] ?? data['f_bottom_font_size']),
      bottomActiveFontSize: _toDoubleOrNull(
        data['bottom_active_font_size'] ?? data['f_bottom_active_font_size'],
      ),
      topNavigationBackgroundColor: _readString(
        data,
        const ['top_navigation_background_color', 'f_top_navigation_background_color'],
      ),
      topFontColor: _readString(data, const ['top_font_color', 'f_top_font_color']),
      loginUrl: (data['login_url'] ?? data['f_login_url'] ?? '').toString(),
      jpushAppKey: (data['jpush_app_key'] ?? data['f_jpush_app_key'] ?? '').toString(),
      isEnable: data['is_enable'] == true || data['f_is_enable'] == true,
    );
  }

  Future<List<AppNavigationItem>> _fetchNavigations(String baseUrl) async {
    final uri = Uri.parse(baseUrl).resolve('/api/${Uri.encodeComponent(kAppCode)}/v1/app_navigations');
    final list = await _getJsonArray(uri);
    final items = list
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => AppNavigationItem(
            id: _toIntOrNull(e['id'] ?? e['f_id']) ?? 0,
            name: (e['name'] ?? e['f_name'] ?? '').toString(),
            icon: (e['icon'] ?? e['f_icon'] ?? '').toString(),
            url: (e['url'] ?? e['f_url'] ?? '').toString(),
            order: _toIntOrNull(e['order'] ?? e['f_order']) ?? 0,
            isEnable: e['is_enable'] == true || e['f_is_enable'] == true,
          ),
        )
        .where((e) => e.isEnable && e.url.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  Future<Map<String, dynamic>> _getJsonObject(Uri uri) async {
    final data = await _getJson(uri);
    if (data is Map<String, dynamic>) return data;
    throw Exception('json object expected');
  }

  Future<List<dynamic>> _getJsonArray(Uri uri) async {
    final data = await _getJson(uri);
    if (data is List<dynamic>) return data;
    throw Exception('json array expected');
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

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
