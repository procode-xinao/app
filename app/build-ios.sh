#!/usr/bin/env bash
set -euo pipefail

# 在 Mac 上、app 目录下执行：按 crm.procode.cn 拉站点信息并构建 iOS（需 Xcode + CocoaPods）

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

SERVICE="${SERVICE:-http://crm.procode.cn:6002/}"
EXT_URL="${APP_EXTERNAL_SERVER_URL:-http://crm.procode.cn:6002}"
INT_URL="${APP_INTERNAL_SERVER_URL:-http://crm.procode.cn:6002}"

echo "==> flutter / dart pub get"
dart pub get

echo "==> CocoaPods (ios/)"
(cd ios && pod install)

echo "==> build ios (release, no codesign — 需在 Xcode 里 Archive 并签名出 IPA)"
dart run tool/build_with_site.dart \
  --service="${SERVICE}" \
  build ios --release --no-codesign \
  --dart-define=APP_EXTERNAL_SERVER_URL="${EXT_URL}" \
  --dart-define=APP_INTERNAL_SERVER_URL="${INT_URL}"

echo ""
echo "Build OK (unsigned .app): build/ios/iphoneos/Runner.app"
echo "上架/真机安装：用 Xcode 打开 ios/Runner.xcworkspace → Product → Archive → Distribute"
