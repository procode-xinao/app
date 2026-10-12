// 从站点拉取 /api/{code}/v1/site，使用 name 作为 APP_DISPLAY_NAME，icon 下载后生成各平台启动图标，再执行 flutter build。
//
// 用法（在 app 目录下）：
//   dart run tool/build_with_site.dart --service=http://web.arsoft.com.cn:6002/ build apk --release
//   dart run tool/build_with_site.dart --service=http://host:6002/ --code=code build ios --release
//
// 若省略 flutter 子命令，默认为：build apk --release

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  String? service;
  var code = 'code';
  final flutterRest = <String>[];
  for (final a in args) {
    if (a.startsWith('--service=')) {
      service = a.substring('--service='.length);
    } else if (a.startsWith('--code=')) {
      code = a.substring('--code='.length);
    } else {
      flutterRest.add(a);
    }
  }

  if (service == null || service.trim().isEmpty) {
    stderr.writeln('缺少 --service=<基础 URL>，例如 --service=http://web.arsoft.com.cn:6002/');
    stderr.writeln(
      '用法: dart run tool/build_with_site.dart --service=<URL> [--code=code] [flutter 参数...]',
    );
    stderr.writeln('默认 flutter 参数: build apk --release');
    exit(64);
  }

  final projectRoot = File(Platform.script.toFilePath()).parent.parent.path;
  final siteUri = Uri.parse(service.trim()).resolve('api/$code/v1/site');

  stdout.writeln('GET $siteUri');
  final client = HttpClient();
  Map<String, dynamic> json;
  try {
    final req = await client.getUrl(siteUri);
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      stderr.writeln('站点接口失败: HTTP ${resp.statusCode}');
      exit(1);
    }
    final raw = await resp.transform(utf8.decoder).join();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('站点接口返回非 JSON 对象');
      exit(1);
    }
    json = decoded;
  } finally {
    client.close(force: true);
  }

  final name = json['name']?.toString().trim();
  final iconUrl = (json['icon'] ?? json['logo'])?.toString().trim();
  if (name == null || name.isEmpty) {
    stderr.writeln('响应中缺少非空字段 name');
    exit(1);
  }
  if (iconUrl == null || iconUrl.isEmpty) {
    stderr.writeln('响应中缺少非空字段 icon');
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

  final flutterArgs = flutterRest.isEmpty ? <String>['build', 'apk', '--release'] : flutterRest;
  final define = '--dart-define=APP_DISPLAY_NAME=$name';
  final full = [...flutterArgs, define];

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

/// flutter_launcher_icons 需要 PNG；站点若返回 SVG 则先栅格化。
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
