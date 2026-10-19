// 从站点拉取 /api/{code}/v1/site（name、icon），再请求 /v1/app（jpush、衬色等），最后 flutter build。
//
// 必填：--service=<服务根 URL>（API 基址，可带末尾 /）
// 可选：--code=<租户 code>（默认 code）
//
// 自动注入 dart-define：
//   APP_EXTERNAL_SERVER_URL / APP_INTERNAL_SERVER_URL ← 由 --service 规范化（去尾斜杠）
//   APP_CODE、APP_DISPLAY_NAME、以及 /v1/app 中的 jpush_app_key、top_background_color 等
//
// 用法（在 app 目录下）：
//   dart run tool/build_with_site.dart --service=http://host:6002/ build apk --release

import 'dart:convert';
import 'dart:io';

Never _usage() {
  stderr.writeln('缺少必填参数 --service=');
  stderr.writeln('');
  stderr.writeln('用法: dart run tool/build_with_site.dart \\');
  stderr.writeln('  --service=<服务根URL> \\');
  stderr.writeln('  [--code=<APP_CODE>] \\');
  stderr.writeln('  [flutter 子命令，默认: build apk --release]');
  stderr.writeln('');
  stderr.writeln('示例:');
  stderr.writeln('  dart run tool/build_with_site.dart \\');
  stderr.writeln('    --service=http://crm.procode.cn:6002/ build apk --release');
  exit(64);
}

String? _parseFlag(List<String> args, String prefix) {
  for (final a in args) {
    if (a.startsWith(prefix)) {
      return a.substring(prefix.length).trim();
    }
  }
  return null;
}

const _scriptFlagPrefixes = ['--service=', '--code='];

/// 与运行时 [Uri.parse(base).resolve('/api/...')] 一致：去掉末尾 `/`。
String _apiBaseFromService(String service) {
  var s = service.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty) {
    stderr.writeln('--service= 无效');
    exit(64);
  }
  return s;
}

Future<Map<String, dynamic>> _getJsonObject(Uri uri, {required String label}) async {
  stdout.writeln('GET $uri');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      stderr.writeln('$label 失败: HTTP ${resp.statusCode}');
      exit(1);
    }
    final raw = await resp.transform(utf8.decoder).join();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('$label 返回非 JSON 对象');
      exit(1);
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>?> _tryFetchAppConfig(String apiBase, String code) async {
  final uri = Uri.parse(apiBase).resolve('/api/${Uri.encodeComponent(code)}/v1/app');
  stdout.writeln('GET $uri（jpush / 衬色等）');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      stdout.writeln('  /v1/app HTTP ${resp.statusCode}，跳过可选 dart-define');
      return null;
    }
    final raw = await resp.transform(utf8.decoder).join();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['is_enable'] != true) {
      stdout.writeln('  /v1/app is_enable != true，跳过可选 dart-define');
      return null;
    }
    return decoded;
  } catch (e) {
    stdout.writeln('  /v1/app 请求失败: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

String _normalizeHexColor(String raw) {
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  return s.toUpperCase();
}

List<String> _stripManagedDartDefines(List<String> args) {
  const managedKeys = {
    'APP_EXTERNAL_SERVER_URL',
    'APP_INTERNAL_SERVER_URL',
    'APP_CODE',
    'APP_DISPLAY_NAME',
    'APP_TOP_BACKGROUND_COLOR',
    'JPUSH_APP_KEY',
    'JPUSH_CHANNEL',
  };
  return args.where((a) {
    if (!a.startsWith('--dart-define=')) return true;
    for (final key in managedKeys) {
      if (a.startsWith('--dart-define=$key=')) return false;
    }
    return true;
  }).toList();
}

Future<void> main(List<String> args) async {
  final serviceRaw = _parseFlag(args, '--service=');
  final codeFlag = _parseFlag(args, '--code=');

  final flutterRest = <String>[];
  for (final a in args) {
    if (_scriptFlagPrefixes.any((p) => a.startsWith(p))) continue;
    flutterRest.add(a);
  }

  if (serviceRaw == null || serviceRaw.isEmpty) {
    _usage();
  }
  final service = serviceRaw;

  final apiBase = _apiBaseFromService(service);
  var code = (codeFlag != null && codeFlag.isNotEmpty) ? codeFlag : 'code';

  stdout.writeln('构建参数:');
  stdout.writeln('  service = $service');
  stdout.writeln('  apiBase = $apiBase');
  stdout.writeln('  code    = $code');
  stdout.writeln('');

  final projectRoot = File(Platform.script.toFilePath()).parent.parent.path;
  final siteUri = Uri.parse(apiBase).resolve('/api/${Uri.encodeComponent(code)}/v1/site');
  final siteJson = await _getJsonObject(siteUri, label: '/v1/site');

  final siteCode = siteJson['code']?.toString().trim();
  if ((codeFlag == null || codeFlag.isEmpty) && siteCode != null && siteCode.isNotEmpty) {
    code = siteCode;
    stdout.writeln('  使用 /v1/site 返回的 code: $code');
  }

  final name = siteJson['name']?.toString().trim();
  final iconUrl = (siteJson['icon'] ?? siteJson['logo'])?.toString().trim();
  if (name == null || name.isEmpty) {
    stderr.writeln('响应中缺少非空字段 name');
    exit(1);
  }
  if (iconUrl == null || iconUrl.isEmpty) {
    stderr.writeln('响应中缺少非空字段 icon/logo');
    exit(1);
  }

  final brandDir = Directory('$projectRoot${Platform.pathSeparator}assets${Platform.pathSeparator}brand');
  await brandDir.create(recursive: true);
  final launcherFile = File('${brandDir.path}${Platform.pathSeparator}launcher_source.png');

  stdout.writeln('下载图标: $iconUrl');
  await _downloadIconToPng(Uri.parse(iconUrl), launcherFile);
  stdout.writeln('已写入 ${launcherFile.path}');

  stdout.writeln('dart pub get');
  var r = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  if (r.exitCode != 0) {
    stderr.writeln(r.stderr);
    exit(r.exitCode);
  }

  stdout.writeln('dart run flutter_launcher_icons');
  r = await Process.run(
    'dart',
    ['run', 'flutter_launcher_icons'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  stdout.writeln(r.stdout);
  if (r.exitCode != 0) {
    stderr.writeln(r.stderr);
    exit(r.exitCode);
  }

  final appConfig = await _tryFetchAppConfig(apiBase, code);

  final flutterArgs =
      _stripManagedDartDefines(flutterRest.isEmpty ? <String>['build', 'apk', '--release'] : flutterRest);
  final defines = <String>[
    '--dart-define=APP_EXTERNAL_SERVER_URL=$apiBase',
    '--dart-define=APP_INTERNAL_SERVER_URL=$apiBase',
    '--dart-define=APP_CODE=$code',
    '--dart-define=APP_DISPLAY_NAME=$name',
  ];

  final jpushAppKey = (appConfig?['jpush_app_key'] ?? '').toString().trim();
  if (jpushAppKey.isNotEmpty) {
    defines.add('--dart-define=JPUSH_APP_KEY=$jpushAppKey');
    defines.add('--dart-define=JPUSH_CHANNEL=default');
  }

  final topColor = (appConfig?['top_background_color'] ?? '').toString().trim();
  if (topColor.isNotEmpty) {
    defines.add('--dart-define=APP_TOP_BACKGROUND_COLOR=${_normalizeHexColor(topColor)}');
  }

  final full = [...flutterArgs, ...defines];

  stdout.writeln('flutter ${full.join(' ')}');
  r = await Process.run(
    'flutter',
    full,
    workingDirectory: projectRoot,
    runInShell: true,
  );
  stdout.writeln(r.stdout);
  if (r.stderr.toString().trim().isNotEmpty) {
    stderr.writeln(r.stderr);
  }
  exit(r.exitCode);
}

Future<List<int>> _downloadBytes(Uri url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      stderr.writeln('下载图标失败: HTTP ${resp.statusCode}');
      exit(1);
    }
    return await resp.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
  } finally {
    client.close(force: true);
  }
}

bool _looksLikeSvg(List<int> bytes, Uri url) {
  if (url.path.toLowerCase().endsWith('.svg')) return true;
  final head = utf8.decode(bytes.take(512).toList(), allowMalformed: true).trimLeft();
  return head.startsWith('<svg') || head.startsWith('<?xml');
}

Future<void> _downloadIconToPng(Uri url, File outPng) async {
  final bytes = await _downloadBytes(url);
  if (!_looksLikeSvg(bytes, url)) {
    await outPng.writeAsBytes(bytes);
    return;
  }

  stdout.writeln('图标为 SVG，正在转换为 PNG…');
  final tmpSvg = File('${outPng.path}.tmp.svg');
  await tmpSvg.writeAsBytes(bytes);
  try {
    await _rasterizeSvgToPng(tmpSvg, outPng);
  } finally {
    if (await tmpSvg.exists()) {
      await tmpSvg.delete();
    }
  }
}

Future<void> _rasterizeSvgToPng(File svg, File png) async {
  const size = '1024';
  final attempts = <List<String>>[
    ['rsvg-convert', '-w', size, '-h', size, svg.path, '-o', png.path],
    ['magick', 'convert', '-background', 'none', svg.path, png.path],
    ['convert', '-background', 'none', svg.path, png.path],
  ];

  Object? lastError;
  for (final cmd in attempts) {
    final exe = cmd.first;
    if (!await _commandExists(exe)) continue;
    final r = await Process.run(cmd.first, cmd.sublist(1), runInShell: false);
    if (r.exitCode == 0 && await png.exists() && await png.length() > 0) {
      return;
    }
    lastError = r.stderr.toString().trim().isEmpty ? r.stdout : r.stderr;
  }

  stderr.writeln('无法将 SVG 转为 PNG。请安装 rsvg-convert（推荐）或 ImageMagick，'
      '或在站点配置 PNG 格式 icon/logo。');
  if (lastError != null) {
    stderr.writeln(lastError);
  }
  exit(1);
}

Future<bool> _commandExists(String name) async {
  if (Platform.isWindows) {
    final r = await Process.run('where', [name], runInShell: true);
    return r.exitCode == 0;
  }
  final r = await Process.run('which', [name], runInShell: true);
  return r.exitCode == 0;
}
