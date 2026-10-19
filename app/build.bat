@echo off
setlocal EnableExtensions

rem 用法: build.bat <SERVICE_URL> [APP_CODE]
rem 详见 app\BUILD.md

if "%~1"=="" (
  echo.
  echo 用法: build.bat ^<SERVICE_URL^> [APP_CODE]
  echo 示例: build.bat http://crm.procode.cn:6002/
  echo.
  exit /b 64
)

set "JAVA_HOME=C:\Program Files\HBuilderX\plugins\amazon-corretto"
set "PATH=C:\Works\flutter_3.41.5\bin;%JAVA_HOME%\bin;%PATH%"
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

cd /d "%~dp0"

echo Building APK...
if "%~2"=="" (
  dart run tool/build_with_site.dart --service=%~1 build apk --release
) else (
  dart run tool/build_with_site.dart --service=%~1 --code=%~2 build apk --release
)

if errorlevel 1 (
  echo.
  echo Build FAILED.
  exit /b 1
)

echo.
echo Build OK: build\app\outputs\flutter-apk\app-release.apk
exit /b 0
