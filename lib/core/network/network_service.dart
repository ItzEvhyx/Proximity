import 'dart:io';

/// Lightweight connectivity check. A successful DNS lookup means the device
/// actually has working internet (not just a network interface that's up).
class NetworkService {
  const NetworkService._();

  static final NetworkService instance = NetworkService._();

  /// Returns true if the device can reach the internet.
  Future<bool> hasConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
