import 'package:app_settings/app_settings.dart';

/// 跳转系统应用设置页。
class AppSettingsService {
  Future<void> openAppSettings() => AppSettings.openAppSettings();
}
