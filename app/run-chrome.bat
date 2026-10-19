@echo off
setlocal EnableExtensions

rem 用法: run-chrome.bat <外网API> <内网API> <APP_CODE>

if "%~3"=="" (
  echo.
  echo 用法: run-chrome.bat ^<外网API^> ^<内网API^> ^<APP_CODE^>
  echo 示例: run-chrome.bat http://crm.procode.cn:6002 http://crm.procode.cn:6002 code
  echo.
  exit /b 64
)

set "PATH=C:\Works\flutter_3.41.5\bin;%PATH%"
cd /d "%~dp0"

flutter pub get
if errorlevel 1 exit /b 1

flutter run -d chrome ^
  --dart-define=APP_EXTERNAL_SERVER_URL=%~1 ^
  --dart-define=APP_INTERNAL_SERVER_URL=%~2 ^
  --dart-define=APP_CODE=%~3

exit /b %ERRORLEVEL%
