import 'package:flutter/services.dart';

import '../../../core/result/device_safety_exception.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/integrity_repository.dart';

/// Platform attestation tokens for your server to verify: Google Play Integrity (Android),
/// Apple App Attest and DeviceCheck (iOS). Tokens prove nothing on the device itself; always
/// verify them server-side (see `example/server_dotnet`).
///
/// Every token method throws [AttestationException] on failure.
final class IntegrityApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.integrity`.
  IntegrityApi(this._repository);

  final IntegrityRepository _repository;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PlatformException catch (e) {
      throw AttestationException.fromPlatform(e);
    } on MissingPluginException {
      throw const AttestationException(AttestationErrorCode.unsupported);
    }
  }

  Future<bool> _supported(bool platformOk, Future<bool> Function() f) async {
    if (!platformOk) return false;
    try {
      return await f();
    } on Object {
      return false;
    }
  }

  /// Fails (through the returned future, never synchronously) when not on [platform].
  Future<T> _on<T>(
    bool platformOk,
    String platform,
    Future<T> Function() f,
  ) async {
    if (!platformOk) {
      throw AttestationException(
        AttestationErrorCode.unsupported,
        message: 'Only available on $platform',
      );
    }
    return _call(f);
  }

  // ------------------------------------------------------------------ Android: Play Integrity

  /// Whether the app bundles `com.google.android.play:integrity` (Android only).
  Future<bool> isPlayIntegrityAvailable() =>
      _supported(PlatformGuard.isAndroid, _repository.isPlayIntegrityAvailable);

  /// Warms up a standard Play Integrity token provider. Call once, early (it can take
  /// seconds); then call [requestPlayIntegrityToken] per protected action.
  Future<void> preparePlayIntegrity({required int cloudProjectNumber}) => _on(
    PlatformGuard.isAndroid,
    'Android',
    () => _repository.preparePlayIntegrity(cloudProjectNumber),
  );

  /// Requests a token bound to [requestHash] (a hash of the action, at most 500 characters).
  /// If it fails with [AttestationErrorCode.providerInvalid], call [preparePlayIntegrity]
  /// again.
  Future<String> requestPlayIntegrityToken({required String requestHash}) =>
      _on(
        PlatformGuard.isAndroid,
        'Android',
        () => _repository.requestPlayIntegrityToken(requestHash),
      );

  // ------------------------------------------------------------------ iOS: App Attest

  /// Whether App Attest works here (real device, entitlement present).
  Future<bool> isAppAttestSupported() =>
      _supported(PlatformGuard.isIOS, _repository.isAppAttestSupported);

  /// Creates a hardware-backed key and returns its id. Store the id; generate a new key only
  /// after [AttestationErrorCode.invalidKey].
  Future<String> generateAppAttestKey() =>
      _on(PlatformGuard.isIOS, 'iOS', _repository.generateAppAttestKey);

  /// Attests [keyId] with a server-issued one-time [challenge] (hashed with SHA-256 on the
  /// device). Returns the base64 attestation object for the server.
  Future<String> attestAppAttestKey({
    required String keyId,
    required String challenge,
  }) => _on(
    PlatformGuard.isIOS,
    'iOS',
    () => _repository.attestAppAttestKey(keyId, challenge),
  );

  /// Signs [clientData] (hashed with SHA-256) with an attested key. Returns a base64
  /// assertion for the server.
  Future<String> generateAppAttestAssertion({
    required String keyId,
    required String clientData,
  }) => _on(
    PlatformGuard.isIOS,
    'iOS',
    () => _repository.generateAppAttestAssertion(keyId, clientData),
  );

  // ------------------------------------------------------------------ iOS: DeviceCheck

  /// Whether DeviceCheck works here.
  Future<bool> isDeviceCheckSupported() =>
      _supported(PlatformGuard.isIOS, _repository.isDeviceCheckSupported);

  /// A base64 DeviceCheck token for Apple's per-device bits API.
  Future<String> generateDeviceCheckToken() =>
      _on(PlatformGuard.isIOS, 'iOS', _repository.generateDeviceCheckToken);
}
