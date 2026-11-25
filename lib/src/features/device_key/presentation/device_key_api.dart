import 'dart:typed_data';

import '../../../core/platform/action_guard.dart';
import '../../../core/utils/platform_guard.dart';
import '../../../core/result/device_key_info.dart';
import '../domain/device_key.dart';

/// A device-bound signing key: an EC P-256 key generated in secure hardware (Android Keystore /
/// StrongBox, iOS Secure Enclave) that can't be copied off the device.
///
/// Typical use: create a key at login, register [DeviceKeyInfo.publicKey] (and on Android the
/// [DeviceKeyInfo.attestationChain]) with your server, then [sign] each sensitive request with
/// a server-issued nonce. A stolen session token alone is then useless on another device.
///
/// Signatures are DER-encoded ECDSA with SHA-256 (verify with `SHA256withECDSA` in Java/Kotlin,
/// `ECDsa.VerifyData(..., DSASignatureFormat.Rfc3279DerSequence)` in .NET, or
/// `ec.ECDSA(hashes.SHA256())` in Python `cryptography`).
///
/// Failures throw `DeviceSafetyException`s (`NativeFailureException` with code `KEY_MISSING`
/// when signing with a key that doesn't exist).
final class DeviceKeyApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.deviceKey`.
  DeviceKeyApi(this._repository);

  final DeviceKeyRepository _repository;

  /// Creates (or replaces) the key [alias]. On Android, pass a server-issued [challenge] to get
  /// an attestation chain your server can verify; [preferStrongBox] uses the StrongBox chip when
  /// the device has one, falling back to the TEE.
  Future<DeviceKeyInfo> create(
    String alias, {
    Uint8List? challenge,
    bool preferStrongBox = true,
  }) => guardAction('deviceKey.create', () {
    PlatformGuard.requireMobile('deviceKey.create');
    return _repository.create(
      alias,
      challenge: challenge,
      preferStrongBox: preferStrongBox,
    );
  });

  /// The existing key's info, or `null` if there's no key [alias].
  Future<DeviceKeyInfo?> info(String alias) =>
      guardAction('deviceKey.info', () => _repository.info(alias));

  /// Signs [data] with the key [alias] (ECDSA P-256 / SHA-256, DER).
  Future<Uint8List> sign(String alias, Uint8List data) =>
      guardAction('deviceKey.sign', () => _repository.sign(alias, data));

  /// Whether the key [alias] exists.
  Future<bool> exists(String alias) =>
      guardAction('deviceKey.exists', () => _repository.exists(alias));

  /// Deletes the key [alias] (no-op if it doesn't exist).
  Future<void> delete(String alias) =>
      guardAction('deviceKey.delete', () => _repository.delete(alias));
}
