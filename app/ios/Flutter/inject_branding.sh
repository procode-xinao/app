#!/bin/sh
# 从项目根目录 branding.properties 或环境变量生成 Branding.xcconfig（由 Xcode 在编译前调用）
set -e
BRANDING_FILE="${SRCROOT}/../branding.properties"
OUT_FILE="${SRCROOT}/Flutter/Branding.xcconfig"

if [ -n "${APP_DISPLAY_NAME:-}" ]; then
  NAME="$APP_DISPLAY_NAME"
elif [ -f "$BRANDING_FILE" ]; then
  NAME=$(grep -m 1 '^displayName=' "$BRANDING_FILE" | sed 's/^displayName=//')
else
  NAME="app"
fi

# xcconfig：带空格的值用双引号包起来
printf 'APP_DISPLAY_NAME = "%s"\n' "$NAME" > "$OUT_FILE"
