@echo off
setlocal EnableExtensions

rem 用法: build.bat <SERVICE_URL> <外网API> <内网API> <APP_CODE>
rem 详见 app\BUILD.md

if "%~4"=="" (
  echo.
  echo 用法: build.bat ^<SERVICE_URL^> ^<外网API^> ^<内网API^> ^<APP_CODE^>
  echo 示例: build.bat http://crm.procode.cn:6002/ http://crm.procode.cn:6002 http://crm.procode.cn:6002 code
  echo.
  exit /b 64
)

set "JAVA_HOME=C:\Program Files\HBuilderX\plugins\amazon-corretto"
set "PATH=C:\Works\flutter_3.41.5\bin;%JAVA_HOME%\bin;%PATH%"
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

cd /d "%~dp0"

echo Building APK...
dart run tool/build_with_site.dart ^
  --service=%~1 ^
  --external-server=%~2 ^
  --internal-server=%~3 ^
  --code=%~4 ^
  build apk --release

if errorlevel 1 (
  echo.
  echo Build FAILED.
  exit /b 1
)

echo.
echo Build OK: build\app\outputs\flutter-apk\app-release.apk
exit /b 0
