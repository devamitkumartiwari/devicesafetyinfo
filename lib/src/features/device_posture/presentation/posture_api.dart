import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/posture_repository.dart';

/// Device posture checks. Each is a separate [DetectionApi] with its own policy:
///
/// | Check | High | Low (strict only) |
/// |---|---|---|
/// | [developerMode] | | developer options on, USB debugging on |
/// | [screenLock] | no secure lock | |
/// | [storeInstall] | | not installed from Play / App Store / TestFlight |
/// | [externalStorage] | | installed on external storage |
/// | [unknownSources] | | may install other apps |
/// | [playProtect] | disabled | state unknown |
///
/// Checks that don't exist on a platform (all but screen lock and store install on iOS) report
/// `CheckStatus.unsupported`.
final class PostureApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.posture`.
  PostureApi(CheckRunner runner, PostureRepository repository)
    : developerMode = _api(CheckType.developerMode, runner, repository),
      screenLock = _api(CheckType.screenLock, runner, repository),
      storeInstall = _api(CheckType.storeInstall, runner, repository),
      externalStorage = _api(CheckType.externalStorage, runner, repository),
      unknownSources = _api(CheckType.unknownSources, runner, repository),
      playProtect = _api(CheckType.playProtect, runner, repository);

  static DetectionApi _api(
    CheckType type,
    CheckRunner runner,
    PostureRepository repository,
  ) => DetectionApi(type, runner, () => repository.report(type));

  /// Developer options or USB debugging enabled (Android).
  final DetectionApi developerMode;

  /// No PIN, pattern, password or biometric lock.
  final DetectionApi screenLock;

  /// Not installed from an official store.
  final DetectionApi storeInstall;

  /// Installed on external storage (Android).
  final DetectionApi externalStorage;

  /// "Install unknown apps" granted to this app (Android).
  final DetectionApi unknownSources;

  /// Google Play Protect disabled or unknown (Android).
  final DetectionApi playProtect;
}
