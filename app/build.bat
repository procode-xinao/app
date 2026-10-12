@echo off
setlocal EnableExtensions

rem 在 app 目录下执行：按 crm.procode.cn 拉站点信息并构建 release APK

set "JAVA_HOME=C:\Program Files\HBuilderX\plugins\amazon-corretto"
set "PATH=C:\Works\flutter_3.41.5\bin;%JAVA_HOME%\bin;%PATH%"
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

cd /d "%~dp0"

echo Building APK...
dart run tool/build_with_site.dart ^
  --service=http://crm.procode.cn:6002/ ^
  build apk --release ^
  --dart-define=APP_EXTERNAL_SERVER_URL=http://crm.procode.cn:6002 ^
  --dart-define=APP_INTERNAL_SERVER_URL=http://crm.procode.cn:6002

if errorlevel 1 (
  echo.
  echo Build FAILED.
  exit /b 1
)

echo.
echo Build OK: build\app\outputs\flutter-apk\app-release.apk
exit /b 0
