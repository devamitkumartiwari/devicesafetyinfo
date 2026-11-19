import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/integrity_repository.dart';

/// Attestation through the platform API.
final class IntegrityRepositoryImpl implements IntegrityRepository {
  /// Creates the repository.
  IntegrityRepositoryImpl(this._platform);

  final IntegrityHostApi _platform;

  @override
  Future<bool> isPlayIntegrityAvailable() =>
      _platform.isPlayIntegrityAvailable();

  @override
  Future<void> preparePlayIntegrity(int cloudProjectNumber) =>
      _platform.preparePlayIntegrity(cloudProjectNumber);

  @override
  Future<String> requestPlayIntegrityToken(String requestHash) =>
      _platform.requestPlayIntegrityToken(requestHash);

  @override
  Future<bool> isAppAttestSupported() => _platform.isAppAttestSupported();

  @override
  Future<String> generateAppAttestKey() => _platform.generateAppAttestKey();

  @override
  Future<String> attestAppAttestKey(String keyId, String challenge) =>
      _platform.attestAppAttestKey(keyId, challenge);

  @override
  Future<String> generateAppAttestAssertion(String keyId, String clientData) =>
      _platform.generateAppAttestAssertion(keyId, clientData);

  @override
  Future<bool> isDeviceCheckSupported() => _platform.isDeviceCheckSupported();

  @override
  Future<String> generateDeviceCheckToken() =>
      _platform.generateDeviceCheckToken();
}
