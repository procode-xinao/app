@echo off
setlocal EnableExtensions

rem iOS 无法在 Windows 上编译，本脚本仅提示；请在 Mac 上使用 build-ios.sh

echo.
echo [提示] Flutter iOS 必须在 macOS 上构建（Xcode + CocoaPods）。
echo.
echo 在 Mac 上进入 app 目录后执行（4 个必填参数，见 BUILD.md）：
echo   chmod +x build-ios.sh
echo   ./build-ios.sh ^<SERVICE_URL^> ^<外网API^> ^<内网API^> ^<APP_CODE^>
echo.
echo 示例:
echo   ./build-ios.sh http://crm.procode.cn:6002/ http://crm.procode.cn:6002 http://crm.procode.cn:6002 code
echo.
exit /b 1
