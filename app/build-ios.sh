#!/usr/bin/env bash
set -euo pipefail

# 用法: ./build-ios.sh <SERVICE_URL> [APP_CODE]

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <SERVICE_URL> [APP_CODE]" >&2
  echo "示例: $0 http://crm.procode.cn:6002/" >&2
  exit 64
fi

SERVICE="$1"
CODE="${2:-}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

echo "==> flutter / dart pub get"
dart pub get

echo "==> CocoaPods (ios/)"
(cd ios && pod install)

CODE_ARGS=()
[[ -n "$CODE" ]] && CODE_ARGS=(--code="$CODE")

echo "==> build ios (release, no codesign)"
dart run tool/build_with_site.dart \
  --service="${SERVICE}" \
  "${CODE_ARGS[@]}" \
  build ios --release --no-codesign

echo ""
echo "Build OK (unsigned .app): build/ios/iphoneos/Runner.app"
