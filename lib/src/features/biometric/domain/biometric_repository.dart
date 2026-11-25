import 'dart:typed_data';

import '../../../core/result/device_key_info.dart';

/// The state of a biometric-bound key.
enum BiometricKeyState {
  /// The key exists and can approve actions.
  valid,

  /// A fingerprint or face was added (or all were removed) since enrollment, so the key can
  /// never be used again. Treat this as a security event: re-verify the user, then enroll again.
  invalidated,

  /// No key was enrolled under this alias.
  missing,
}

/// Biometric-bound keys.
abstract interface class BiometricRepository {
  Future<bool> isAvailable();
  Future<DeviceKeyInfo> enroll(String alias);
  Future<Uint8List> approve(
    String alias,
    Uint8List payload, {
    required String title,
    required String reason,
  });
  Future<BiometricKeyState> keyState(String alias);
  Future<void> delete(String alias);
}
