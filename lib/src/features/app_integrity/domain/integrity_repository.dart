/// Platform attestation: Play Integrity (Android), App Attest and DeviceCheck (iOS).
abstract interface class IntegrityRepository {
  Future<bool> isPlayIntegrityAvailable();
  Future<void> preparePlayIntegrity(int cloudProjectNumber);
  Future<String> requestPlayIntegrityToken(String requestHash);
  Future<bool> isAppAttestSupported();
  Future<String> generateAppAttestKey();
  Future<String> attestAppAttestKey(String keyId, String challenge);
  Future<String> generateAppAttestAssertion(String keyId, String clientData);
  Future<bool> isDeviceCheckSupported();
  Future<String> generateDeviceCheckToken();
}
