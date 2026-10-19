@echo off
setlocal EnableExtensions

rem 用法: run-windows.bat <外网API> <内网API> <APP_CODE>

if "%~3"=="" (
  echo.
  echo 用法: run-windows.bat ^<外网API^> ^<内网API^> ^<APP_CODE^>
  echo 示例: run-windows.bat http://crm.procode.cn:6002 http://crm.procode.cn:6002 code
  echo.
  exit /b 64
)

set "PATH=C:\Works\flutter_3.41.5\bin;%PATH%"
cd /d "%~dp0"

echo 若提示 symlink，请在 设置 -^> 开发者选项 中打开「开发人员模式」后重试。
echo.

flutter pub get
if errorlevel 1 exit /b 1

flutter run -d windows ^
  --dart-define=APP_EXTERNAL_SERVER_URL=%~1 ^
  --dart-define=APP_INTERNAL_SERVER_URL=%~2 ^
  --dart-define=APP_CODE=%~3

exit /b %ERRORLEVEL%
