import 'dart:convert';

import 'package:meta/meta.dart';

/// Which public keys each host may present.
///
/// [pins] maps a host name to the base64 SHA-256 pins of the SubjectPublicKeyInfo its **leaf**
/// certificate may have (see `spkiSha256`). Give at least two per host: the current key and a
/// backup key you keep offline, so a key change doesn't lock users out. Renew certificates with
/// the same key (e.g. certbot `--reuse-key`) or ship the new pin before switching.
///
/// Hosts not listed get normal TLS validation only.
@immutable
final class PinningConfig {
  /// Creates the config. Throws [ArgumentError] when a host has fewer than two pins or a pin
  /// isn't a base64 SHA-256 digest.
  PinningConfig(Map<String, Set<String>> pins, {this.includeSubdomains = false})
    : pins = Map.unmodifiable({
        for (final MapEntry(:key, :value) in pins.entries)
          key.toLowerCase(): Set<String>.unmodifiable(value),
      }) {
    for (final MapEntry(:key, :value) in this.pins.entries) {
      if (value.length < 2) {
        throw ArgumentError.value(
          key,
          'pins',
          'pin at least two keys (current and backup)',
        );
      }
      for (final pin in value) {
        if (!_isSha256Base64(pin)) {
          throw ArgumentError.value(pin, 'pins', 'not a base64 SHA-256 pin');
        }
      }
    }
  }

  /// Host name (lower case) to allowed pins.
  final Map<String, Set<String>> pins;

  /// Whether a host's pins also cover its subdomains (`api.example.com` under `example.com`).
  final bool includeSubdomains;

  /// The pins for [host], or `null` if it isn't pinned.
  Set<String>? pinsFor(String host) {
    var h = host.toLowerCase();
    if (pins[h] case final p?) return p;
    if (!includeSubdomains) return null;
    for (var i = h.indexOf('.'); i != -1; i = h.indexOf('.')) {
      h = h.substring(i + 1);
      if (pins[h] case final p?) return p;
    }
    return null;
  }

  static bool _isSha256Base64(String pin) {
    try {
      return base64.decode(pin).length == 32;
    } on FormatException {
      return false;
    }
  }
}
