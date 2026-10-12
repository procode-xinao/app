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
  await _downloadToFile(Uri.parse(iconUrl), launcherFile);
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

Future<void> _downloadToFile(Uri url, File out) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      stderr.writeln('下载图标失败: HTTP ${resp.statusCode}');
      exit(1);
    }
    final sink = out.openWrite();
    try {
      await sink.addStream(resp);
    } finally {
      await sink.close();
    }
  } finally {
    client.close(force: true);
  }
}
