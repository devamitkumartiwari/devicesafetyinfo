import 'dart:io';
import 'dart:typed_data';

import '../../../core/result/device_safety_exception.dart';
import '../domain/pinning_config.dart';
import '../domain/spki.dart';

/// Called when a pinned host presents a key that isn't pinned ([seenPin] is its pin, or
/// `none` without a certificate).
typedef PinViolationHandler = void Function(String host, String seenPin);

/// An [HttpClient] that checks [config]'s pins during the TLS handshake, before any request
/// bytes are sent. Connections are always direct (no proxy), and plain HTTP to a pinned host
/// is refused.
HttpClient createPinnedHttpClient(
  PinningConfig config, {
  SecurityContext? context,
  required PinViolationHandler onViolation,
}) {
  final client = HttpClient(context: context)..findProxy = (_) => 'DIRECT';
  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    final pins = config.pinsFor(uri.host);
    if (uri.scheme != 'https') {
      if (pins != null) {
        throw PinningException(uri.host, 'plain HTTP to a pinned host');
      }
      return Socket.startConnect(uri.host, uri.port);
    }
    final task = await SecureSocket.startConnect(
      uri.host,
      uri.port,
      context: context,
    );
    if (pins == null) return task;
    return ConnectionTask.fromSocket(
      task.socket.then((socket) {
        final der = socket.peerCertificate?.der;
        final seen = der == null ? 'none' : _pinOrInvalid(der);
        if (pins.contains(seen)) return socket;
        socket.destroy();
        onViolation(uri.host, seen);
        throw PinningException(uri.host, 'no pinned key matched');
      }),
      task.cancel,
    );
  };
  return client;
}

String _pinOrInvalid(Uint8List der) {
  try {
    return spkiSha256(der);
  } on FormatException {
    return 'invalid';
  }
}
