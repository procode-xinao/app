@echo off
setlocal EnableExtensions

rem iOS 无法在 Windows 上编译，本脚本仅提示；请在 Mac 上使用 build-ios.sh

echo.
echo [提示] Flutter iOS 必须在 macOS 上构建（Xcode + CocoaPods）。
echo.
echo 在 Mac 上进入本目录后执行：
echo   chmod +x build-ios.sh
echo   ./build-ios.sh
echo.
echo 或手动一条命令（Mac 终端）：
echo   dart run tool/build_with_site.dart --service=http://crm.procode.cn:6002/ build ios --release --no-codesign --dart-define=APP_EXTERNAL_SERVER_URL=http://crm.procode.cn:6002 --dart-define=APP_INTERNAL_SERVER_URL=http://crm.procode.cn:6002
echo.
exit /b 1
