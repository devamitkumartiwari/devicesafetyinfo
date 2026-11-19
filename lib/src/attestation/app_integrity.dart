import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';
import 'attestation_exception.dart';

/// Client side of platform attestation: **Google Play Integrity** (Android) and **Apple App
/// Attest / DeviceCheck** (iOS).
///
/// Every method here only *produces* an opaque, signed token. A token proves nothing until **your
/// server** verifies it with Google / Apple — never decide trust on-device, because an attacker who
/// controls the device can patch any local check. See `example/server_dotnet` for a reference
/// verifier and the README section "App Integrity" for the full flow.
///
/// All failures throw [AttestationException].
class AppIntegrity {
  AppIntegrity._();

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await DeviceSafetyChannels.method.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw AttestationException.fromPlatform(e);
    } on MissingPluginException {
      throw const AttestationException(AttestationErrorCode.unsupported);
    }
  }

  static Future<String> _callString(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final value = await _call<String>(method, args);
    if (value == null) {
      throw AttestationException(
        AttestationErrorCode.unknown,
        message: '$method returned no data',
      );
    }
    return value;
  }

  static Never _unsupported(String platform) => throw AttestationException(
    AttestationErrorCode.unsupported,
    message: 'Only available on $platform',
  );

  // ---------------------------------------------------------------------------------------------
  // Android — Google Play Integrity (standard requests)
  // ---------------------------------------------------------------------------------------------

  /// `true` on Android when the app has added the opt-in
  /// `com.google.android.play:integrity` Gradle dependency. Always `false` on other platforms.
  static Future<bool> get isPlayIntegrityAvailable async {
    if (!_android) return false;
    try {
      return await _call<bool>('isPlayIntegrityAvailable') ?? false;
    } on AttestationException {
      return false;
    }
  }

  /// Warms up a Play Integrity token provider. Call once, early (e.g. at app start), with the
  /// Google Cloud project number linked to your app in Play Console.
  ///
  /// Call again after an [AttestationErrorCode.providerInvalid] error.
  static Future<void> preparePlayIntegrity({
    required int cloudProjectNumber,
  }) async {
    if (!_android) _unsupported('Android');
    await _call<void>('preparePlayIntegrity', {
      'cloudProjectNumber': cloudProjectNumber,
    });
  }

  /// Requests an integrity token bound to [requestHash] (at most 500 characters).
  ///
  /// Use a one-time challenge from your server — or `base64url(SHA256(challenge + payload))` to
  /// also bind the request body. Send the returned token to your server, which decodes it with
  /// Google's `decodeIntegrityToken` API and checks `requestDetails.requestHash`.
  static Future<String> requestPlayIntegrityToken({
    required String requestHash,
  }) async {
    if (!_android) _unsupported('Android');
    return _callString('requestPlayIntegrityToken', {
      'requestHash': requestHash,
    });
  }

  // ---------------------------------------------------------------------------------------------
  // iOS — App Attest
  // ---------------------------------------------------------------------------------------------

  /// `true` on iOS devices that support App Attest. `false` on the simulator, in most app
  /// extensions, and on every non-iOS platform.
  static Future<bool> get isAppAttestSupported async {
    if (!_ios) return false;
    try {
      return await _call<bool>('isAppAttestSupported') ?? false;
    } on AttestationException {
      return false;
    }
  }

  /// Generates a new Secure Enclave key and returns its `keyId`.
  ///
  /// Do this once per install, attest it with [attestAppAttestKey], then persist the keyId
  /// (it isn't secret — the private key never leaves the Secure Enclave — so e.g.
  /// `shared_preferences` is fine).
  static Future<String> generateAppAttestKey() async {
    if (!_ios) _unsupported('iOS');
    return _callString('generateAppAttestKey');
  }

  /// Attests [keyId] once, bound to a one-time server [challenge]. Returns the attestation object
  /// as base64 CBOR, to send to your server with the keyId and challenge.
  ///
  /// The plugin hashes [challenge] as `SHA256(utf8(challenge))`; the server must do the same.
  static Future<String> attestAppAttestKey({
    required String keyId,
    required String challenge,
  }) async {
    if (!_ios) _unsupported('iOS');
    return _callString('attestAppAttestKey', {
      'keyId': keyId,
      'challenge': challenge,
    });
  }

  /// Signs [clientData] (typically the request body, including a server nonce) with the attested
  /// key. Returns the assertion as base64 CBOR, to send alongside the request.
  ///
  /// The plugin hashes [clientData] as `SHA256(utf8(clientData))`; the server must do the same.
  static Future<String> generateAppAttestAssertion({
    required String keyId,
    required String clientData,
  }) async {
    if (!_ios) _unsupported('iOS');
    return _callString('generateAppAttestAssertion', {
      'keyId': keyId,
      'clientData': clientData,
    });
  }

  // ---------------------------------------------------------------------------------------------
  // iOS — DeviceCheck
  // ---------------------------------------------------------------------------------------------

  /// `true` on iOS devices that support DeviceCheck. `false` on every non-iOS platform.
  static Future<bool> get isDeviceCheckSupported async {
    if (!_ios) return false;
    try {
      return await _call<bool>('isDeviceCheckSupported') ?? false;
    } on AttestationException {
      return false;
    }
  }

  /// Returns a base64 DeviceCheck token. Your server uses it with Apple's
  /// `validate_device_token`, `query_two_bits` and `update_two_bits` APIs (e.g. to remember
  /// "this device already redeemed the promo" across reinstalls).
  static Future<String> generateDeviceCheckToken() async {
    if (!_ios) _unsupported('iOS');
    return _callString('generateDeviceCheckToken');
  }
}
