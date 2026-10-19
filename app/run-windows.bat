@echo off
setlocal EnableExtensions

rem 用法: run-windows.bat <SERVICE_URL> [APP_CODE]
rem API 基址由 SERVICE 推导（去尾斜杠），与构建脚本一致。

if "%~1"=="" (
  echo.
  echo 用法: run-windows.bat ^<SERVICE_URL^> [APP_CODE]
  echo 示例: run-windows.bat http://crm.procode.cn:6002/
  echo.
  exit /b 64
)

set "PATH=C:\Works\flutter_3.41.5\bin;%PATH%"
cd /d "%~dp0"

set "SERVICE=%~1"
if "%SERVICE:~-1%"=="/" set "SERVICE=%SERVICE:~0,-1%"
set "CODE=%~2"
if "%CODE%"=="" set "CODE=code"

echo 若提示 symlink，请在 设置 -^> 开发者选项 中打开「开发人员模式」后重试。
echo.

flutter pub get
if errorlevel 1 exit /b 1

flutter run -d windows ^
  --dart-define=APP_EXTERNAL_SERVER_URL=%SERVICE% ^
  --dart-define=APP_INTERNAL_SERVER_URL=%SERVICE% ^
  --dart-define=APP_CODE=%CODE%

exit /b %ERRORLEVEL%
