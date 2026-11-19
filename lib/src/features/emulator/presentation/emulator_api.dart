import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/emulator_repository.dart';

/// Emulator (Android) and simulator (iOS) detection.
///
/// High-risk: emulator hardware (goldfish, ranchu), QEMU properties, emulator-only build
/// names, the iOS simulator. Low-risk (strict only): generic or unknown build fields, which
/// some budget phones and custom ROMs also report.
final class EmulatorApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.emulator`.
  EmulatorApi(CheckRunner runner, EmulatorRepository repository)
    : super(CheckType.emulator, runner, repository.emulatorReport);
}
