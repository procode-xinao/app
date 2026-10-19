@echo off
setlocal EnableExtensions

echo.
echo [提示] Flutter iOS 必须在 macOS 上构建。
echo.
echo   ./build-ios.sh ^<SERVICE_URL^> [APP_CODE]
echo   示例: ./build-ios.sh http://crm.procode.cn:6002/
echo.
exit /b 1
