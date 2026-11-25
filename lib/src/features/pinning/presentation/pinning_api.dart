import 'dart:io';

import '../../../core/result/check_type.dart';
import '../../../core/threats/threat_bus.dart';
import '../data/pinned_http_client.dart';
import '../domain/pinning_config.dart';
import '../domain/spki.dart';

export '../domain/pinning_config.dart';
export '../domain/spki.dart' show spkiSha256;

/// TLS certificate pinning for your own API traffic (pure Dart, Android and iOS).
///
/// Stops interception even when a proxy's CA is trusted on the device (see `DeviceSafety.mitm`).
/// The check runs during the TLS handshake, before any request bytes leave the device. A
/// mismatch throws `PinningException` and emits a threat event (`CheckType.mitm`, detail
/// `pin_mismatch:<host>`).
///
/// ```dart
/// final pins = PinningConfig({
///   'api.example.com': {'current-pin-base64=', 'backup-pin-base64='},
/// });
/// final client = IOClient(DeviceSafety.pinning.createHttpClient(pins));    // package:http
/// dio.httpClientAdapter = IOHttpClientAdapter(
///   createHttpClient: () => DeviceSafety.pinning.createHttpClient(pins),  // dio
/// );
/// ```
///
/// Only the leaf certificate's key can be pinned (Dart exposes only the peer certificate).
/// Connections from this client never use a proxy.
final class PinningApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.pinning`.
  PinningApi(this._threats);

  final ThreatBus _threats;

  /// An [HttpClient] that enforces [config]. Pass [context] for custom trusted roots.
  HttpClient createHttpClient(
    PinningConfig config, {
    SecurityContext? context,
  }) => createPinnedHttpClient(
    config,
    context: context,
    onViolation: (host, _) =>
        _threats.emit(CheckType.mitm, 'pin_mismatch:$host'),
  );

  /// Connects to [uri]'s host and returns the pin of the certificate it presents. For setting
  /// up pins in development; don't trust a pin fetched over a network you don't control.
  Future<String> spkiPinOf(
    Uri uri, {
    SecurityContext? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = await SecureSocket.connect(
      uri.host,
      uri.hasPort ? uri.port : 443,
      context: context,
      timeout: timeout,
    );
    try {
      final cert = socket.peerCertificate;
      if (cert == null) {
        throw const TlsException('The server sent no certificate');
      }
      return spkiSha256(cert.der);
    } finally {
      socket.destroy();
    }
  }
}
