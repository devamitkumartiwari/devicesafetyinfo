import 'package:flutter/services.dart';

/// Why an [AppIntegrity] call failed.
enum AttestationErrorCode {
  /// Not available here: wrong platform, iOS simulator / app extension, missing App Attest
  /// entitlement, or (Android) the app hasn't added the `com.google.android.play:integrity`
  /// dependency.
  unsupported,

  /// (Android) `requestPlayIntegrityToken` was called before `preparePlayIntegrity`.
  notPrepared,

  /// (Android) The prepared token provider expired or became invalid. Call
  /// `preparePlayIntegrity` again, then retry.
  providerInvalid,

  /// (Android) Google Play Store / Play services missing or outdated on this device.
  playServicesUnavailable,

  /// Network error while talking to Google / Apple. Retry with backoff.
  network,

  /// (Android) Play Integrity quota or rate limit hit. Retry later with backoff.
  tooManyRequests,

  /// (iOS) The App Attest key is no longer valid. Discard the stored keyId, generate a new key,
  /// and attest it again.
  invalidKey,

  /// A required argument was missing or malformed (e.g. requestHash longer than 500 chars,
  /// invalid cloud project number).
  invalidInput,

  /// (iOS) Apple's attestation service is temporarily unavailable. Retry later.
  serverUnavailable,

  /// Any other platform error — see [AttestationException.platformCode].
  unknown,
}

/// Thrown by every [AppIntegrity] method when a token can't be produced.
class AttestationException implements Exception {
  const AttestationException(this.code, {this.message, this.platformCode});

  /// Maps a native [PlatformException] (whose `code` is one of the plugin's attestation error
  /// strings) to an [AttestationException].
  factory AttestationException.fromPlatform(PlatformException e) =>
      AttestationException(
        switch (e.code) {
          'UNSUPPORTED' => AttestationErrorCode.unsupported,
          'NOT_PREPARED' => AttestationErrorCode.notPrepared,
          'PROVIDER_INVALID' => AttestationErrorCode.providerInvalid,
          'PLAY_SERVICES_UNAVAILABLE' =>
            AttestationErrorCode.playServicesUnavailable,
          'NETWORK' => AttestationErrorCode.network,
          'TOO_MANY_REQUESTS' => AttestationErrorCode.tooManyRequests,
          'INVALID_KEY' => AttestationErrorCode.invalidKey,
          'INVALID_INPUT' => AttestationErrorCode.invalidInput,
          'SERVER_UNAVAILABLE' => AttestationErrorCode.serverUnavailable,
          _ => AttestationErrorCode.unknown,
        },
        message: e.message,
        platformCode: e.code,
      );

  /// The normalized failure reason.
  final AttestationErrorCode code;

  /// Human-readable detail from the platform, if any.
  final String? message;

  /// The raw native error code, e.g. `PLAY_INTEGRITY_-12` for an unmapped Play Integrity error.
  final String? platformCode;

  @override
  String toString() =>
      'AttestationException(${code.name}${platformCode == null ? '' : ', $platformCode'})'
      '${message == null ? '' : ': $message'}';
}
