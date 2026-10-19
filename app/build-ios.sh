#!/usr/bin/env bash
set -euo pipefail

# 用法: ./build-ios.sh <SERVICE_URL> <外网API> <内网API> <APP_CODE>
# 详见 BUILD.md

if [[ $# -lt 4 ]]; then
  echo "用法: $0 <SERVICE_URL> <外网API> <内网API> <APP_CODE>" >&2
  echo "示例: $0 http://crm.procode.cn:6002/ http://crm.procode.cn:6002 http://crm.procode.cn:6002 code" >&2
  exit 64
fi

SERVICE="$1"
EXTERNAL="$2"
INTERNAL="$3"
CODE="$4"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

echo "==> flutter / dart pub get"
dart pub get

echo "==> CocoaPods (ios/)"
(cd ios && pod install)

echo "==> build ios (release, no codesign — 需在 Xcode 里 Archive 并签名出 IPA)"
dart run tool/build_with_site.dart \
  --service="${SERVICE}" \
  --external-server="${EXTERNAL}" \
  --internal-server="${INTERNAL}" \
  --code="${CODE}" \
  build ios --release --no-codesign

echo ""
echo "Build OK (unsigned .app): build/ios/iphoneos/Runner.app"
echo "上架/真机安装：用 Xcode 打开 ios/Runner.xcworkspace → Product → Archive → Distribute"
