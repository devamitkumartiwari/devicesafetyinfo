import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/tampering_signals.dart';

/// Reads signing information through the platform API.
final class TamperingRepositoryImpl implements TamperingRepository {
  /// Creates the repository.
  TamperingRepositoryImpl(this._platform);

  final AppInfoHostApi _platform;

  @override
  Future<SigningInfo> signingInfo() async =>
      (await _platform.signingInfo()).toDomain();
}

/// Converts the platform message.
extension SigningInfoMsgMapping on SigningInfoMsg {
  /// The domain value.
  SigningInfo toDomain() => SigningInfo(
    certificateSha256: certificateSha256,
    hasProvisioningProfile: hasProvisioningProfile,
    teamId: teamId,
  );
}
