import 'package:flutter/services.dart';

/// Thrown by action APIs (blocking screenshots, secure copy, attestation, ...). Detection APIs
/// never throw; they report failures through `CheckResult.status`.
sealed class DeviceSafetyException implements Exception {
  const DeviceSafetyException(this.message);

  /// Human-readable detail, if any.
  final String? message;
}

/// The operation isn't available on this platform.
final class UnsupportedPlatformException extends DeviceSafetyException {
  /// Creates the exception for [operation].
  const UnsupportedPlatformException(this.operation, [super.message]);

  /// The operation that was attempted, e.g. `hideFromRecents`.
  final String operation;

  @override
  String toString() =>
      'UnsupportedPlatformException($operation)'
      '${message == null ? '' : ': $message'}';
}

/// The app hasn't declared or been granted a permission the operation needs.
final class PermissionMissingException extends DeviceSafetyException {
  /// Creates the exception for [permission].
  const PermissionMissingException(this.permission, [super.message]);

  /// The missing permission, e.g. `android.permission.READ_PHONE_STATE`.
  final String permission;

  @override
  String toString() =>
      'PermissionMissingException($permission)'
      '${message == null ? '' : ': $message'}';
}

/// The platform side failed.
final class NativeFailureException extends DeviceSafetyException {
  /// Creates the exception.
  const NativeFailureException(this.code, [super.message, this.details]);

  /// Wraps a [PlatformException] from a platform call.
  factory NativeFailureException.fromPlatform(PlatformException e) =>
      NativeFailureException(e.code, e.message, e.details);

  /// The native error code.
  final String code;

  /// Extra native detail, if any.
  final Object? details;

  @override
  String toString() =>
      'NativeFailureException($code)${message == null ? '' : ': $message'}';
}

/// Why an attestation call failed.
enum AttestationErrorCode {
  /// Not available here: wrong platform, iOS simulator or app extension, missing App Attest
  /// entitlement, or (Android) the app hasn't added the `com.google.android.play:integrity`
  /// dependency.
  unsupported,

  /// (Android) `requestPlayIntegrityToken` was called before `preparePlayIntegrity`.
  notPrepared,

  /// (Android) The prepared token provider expired or became invalid. Call
  /// `preparePlayIntegrity` again, then retry.
  providerInvalid,

  /// (Android) Google Play Store or Play services are missing or outdated.
  playServicesUnavailable,

  /// Network error while talking to Google or Apple. Retry with backoff.
  network,

  /// (Android) Play Integrity quota or rate limit hit. Retry later with backoff.
  tooManyRequests,

  /// (iOS) The App Attest key is no longer valid. Discard the stored key id, generate a new
  /// key, and attest it again.
  invalidKey,

  /// A required argument was missing or malformed (e.g. a request hash longer than 500
  /// characters, an invalid cloud project number).
  invalidInput,

  /// (iOS) Apple's attestation service is temporarily unavailable. Retry later.
  serverUnavailable,

  /// Any other platform error; see [AttestationException.platformCode].
  unknown,
}

/// Thrown by the integrity APIs when a token can't be produced.
final class AttestationException extends DeviceSafetyException {
  /// Creates the exception.
  const AttestationException(this.code, {String? message, this.platformCode})
    : super(message);

  /// Maps a platform error (whose code is one of the plugin's attestation error strings).
  factory AttestationException.fromPlatform(PlatformException e) =>
      AttestationException(
        switch (e.code) {
          'UNSUPPORTED' => .unsupported,
          'NOT_PREPARED' => .notPrepared,
          'PROVIDER_INVALID' => .providerInvalid,
          'PLAY_SERVICES_UNAVAILABLE' => .playServicesUnavailable,
          'NETWORK' => .network,
          'TOO_MANY_REQUESTS' => .tooManyRequests,
          'INVALID_KEY' => .invalidKey,
          'INVALID_INPUT' => .invalidInput,
          'SERVER_UNAVAILABLE' => .serverUnavailable,
          _ => .unknown,
        },
        message: e.message,
        platformCode: e.code,
      );

  /// The normalized failure reason.
  final AttestationErrorCode code;

  /// The raw native error code, e.g. `PLAY_INTEGRITY_-12` for an unmapped Play Integrity error.
  final String? platformCode;

  @override
  String toString() =>
      'AttestationException(${code.name}${platformCode == null ? '' : ', $platformCode'})'
      '${message == null ? '' : ': $message'}';
}

/// Why a biometric operation failed.
enum BiometricErrorCode {
  /// No usable strong biometric hardware, or the OS is too old (Android 10+ is required).
  unavailable,

  /// No fingerprint or face is enrolled.
  notEnrolled,

  /// The user cancelled the prompt.
  cancelled,

  /// Too many failed attempts; biometrics are locked for now.
  lockedOut,

  /// A fingerprint or face was added (or all were removed) since the key was enrolled. The key
  /// is permanently unusable: confirm the user's identity another way, then enroll again.
  enrollmentChanged,

  /// No key exists for the alias; call `enroll` first.
  keyMissing,

  /// Anything else; see [BiometricException.platformCode].
  failed,
}

/// Thrown by `DeviceSafety.biometric` operations.
final class BiometricException extends DeviceSafetyException {
  /// Creates the exception.
  const BiometricException(this.code, {String? message, this.platformCode})
    : super(message);

  /// Maps a platform error from the biometric host API.
  factory BiometricException.fromPlatform(PlatformException e) =>
      BiometricException(
        switch (e.code) {
          'UNSUPPORTED' => .unavailable,
          'NOT_ENROLLED' => .notEnrolled,
          'CANCELLED' => .cancelled,
          'LOCKED_OUT' => .lockedOut,
          'ENROLLMENT_CHANGED' => .enrollmentChanged,
          'KEY_MISSING' => .keyMissing,
          _ => .failed,
        },
        message: e.message,
        platformCode: e.code,
      );

  /// The normalized failure reason.
  final BiometricErrorCode code;

  /// The raw native error code.
  final String? platformCode;

  @override
  String toString() =>
      'BiometricException(${code.name})${message == null ? '' : ': $message'}';
}
