/// 应用对外显示名（任务切换器、MaterialApp.title 等）。
///
/// **构建参数覆盖**：`flutter run` / `flutter build` 时加
/// `--dart-define=APP_DISPLAY_NAME=你的应用名`
///
/// **默认值**（与 [String.fromEnvironment] 的 `defaultValue` 一致）：
/// - Android：未传 dart-define 时使用 `android/gradle.properties` 里的 `flutter.appDisplayName`
/// - Dart：下面 `defaultValue` 请与 `flutter.appDisplayName` 保持同步
/// - iOS：`ios/Flutter/AppName.xcconfig` 中的 `APP_DISPLAY_NAME`
/// - Windows：`windows/runner/Runner.rc` 中的 `ProductName` / `FileDescription`
const String kAppDisplayName = String.fromEnvironment(
  'APP_DISPLAY_NAME',
  defaultValue: '我的应用',
);
