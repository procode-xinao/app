import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络连接类型（不保证一定能访问公网，仅表示链路状态）。
class NetworkService {
  Future<Map<String, dynamic>> getStatus() async {
    final results = await Connectivity().checkConnectivity();
    final types = results.map((e) => e.name).toList();
    final hasLink = results.any((r) => r != ConnectivityResult.none);
    return {
      'types': types,
      'hasNetwork': hasLink,
    };
  }
}
