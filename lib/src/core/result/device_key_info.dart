import 'dart:typed_data';

/// Where a key's private part lives.
enum KeySecurityLevel {
  /// A dedicated secure chip (Android StrongBox).
  strongBox,

  /// The trusted execution environment (Android TEE).
  tee,

  /// The iOS Secure Enclave.
  secureEnclave,

  /// Software only: no secure hardware (emulators, the iOS simulator, very old devices).
  software;

  /// Whether the private key is protected by secure hardware.
  bool get isHardwareBacked => this != software;
}

/// A hardware-bound key's public information.
final class DeviceKeyInfo {
  /// Creates the info.
  const DeviceKeyInfo({
    required this.publicKey,
    required this.securityLevel,
    this.attestationChain = const [],
  });

  /// The SubjectPublicKeyInfo (DER) of the EC P-256 public key. Send it to your server once to
  /// register the device.
  final Uint8List publicKey;

  /// Where the private key lives.
  final KeySecurityLevel securityLevel;

  /// (Android) The key attestation certificate chain, leaf first (DER). Your server verifies it
  /// up to Google's attestation root and reads the challenge, verified boot state and
  /// security level from the leaf. Empty on iOS (use App Attest there) and when the device
  /// doesn't support attestation.
  final List<Uint8List> attestationChain;
}
