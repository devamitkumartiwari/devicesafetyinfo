import 'package:flutter/services.dart';

import '../../../core/result/device_safety_exception.dart';
import '../../../core/utils/platform_guard.dart';
import '../../../core/result/device_key_info.dart';
import '../domain/biometric_repository.dart';

export '../domain/biometric_repository.dart' show BiometricKeyState;

/// Biometric-approved actions (Android 10+, iOS).
///
/// Unlike a plain "authenticate" call that returns `true`, an approval is a **signature** made by
/// a key that the OS releases only after a strong fingerprint or face match. Hooking the success
/// callback can't produce it, and your server can verify it with the public key from [enroll].
///
/// The key is invalidated when a new fingerprint or face is enrolled, so someone who adds their
/// own finger to an unlocked phone can't approve anything: [keyState] reports
/// [BiometricKeyState.invalidated] and [approve] throws
/// [BiometricErrorCode.enrollmentChanged].
///
/// ```dart
/// final key = await DeviceSafety.biometric.enroll('payments');      // register key.publicKey
/// final signature = await DeviceSafety.biometric.approve(
///   'payments',
///   utf8.encode(serverNonce + paymentJson),
///   title: 'Confirm payment',
///   reason: 'Pay ₹500 to Alice',
/// );                                                                  // send to your server
/// ```
///
/// iOS needs `NSFaceIDUsageDescription` in `Info.plist`. Every method throws
/// [BiometricException] on failure.
final class BiometricApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.biometric`.
  BiometricApi(this._repository);

  final BiometricRepository _repository;

  Future<T> _call<T>(Future<T> Function() f) async {
    if (!PlatformGuard.isSupported) {
      throw const BiometricException(
        BiometricErrorCode.unavailable,
        message: 'Android and iOS only',
      );
    }
    try {
      return await f();
    } on PlatformException catch (e) {
      throw BiometricException.fromPlatform(e);
    } on MissingPluginException {
      throw const BiometricException(BiometricErrorCode.unavailable);
    }
  }

  /// Whether a strong biometric is enrolled and usable.
  Future<bool> isAvailable() async {
    try {
      return await _call(_repository.isAvailable);
    } on BiometricException {
      return false;
    }
  }

  /// Creates (or replaces) the biometric-bound key [alias] and returns its public key for your
  /// server.
  Future<DeviceKeyInfo> enroll(String alias) =>
      _call(() => _repository.enroll(alias));

  /// Shows the biometric prompt ([title], [reason]) and, on a match, returns the signature over
  /// [payload] (ECDSA P-256 / SHA-256, DER). Include a server-issued nonce in [payload] so the
  /// signature can't be replayed.
  Future<Uint8List> approve(
    String alias,
    Uint8List payload, {
    required String title,
    required String reason,
  }) => _call(
    () => _repository.approve(alias, payload, title: title, reason: reason),
  );

  /// Whether the key [alias] is usable, was invalidated by an enrollment change, or is missing.
  Future<BiometricKeyState> keyState(String alias) =>
      _call(() => _repository.keyState(alias));

  /// Deletes the key [alias].
  Future<void> delete(String alias) => _call(() => _repository.delete(alias));
}
