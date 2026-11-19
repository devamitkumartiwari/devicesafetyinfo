import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/root_repository.dart';

/// Root (Android) and jailbreak (iOS) detection.
///
/// High-risk signals: an executable `su`, Magisk or Superuser artifacts, `ro.secure=0`, a
/// failed IOSSecuritySuite jailbreak check, root files found by the native C check. Low-risk
/// (strict policy only): busybox, a non-executable `su`, `test-keys`, an unlocked bootloader,
/// a `cydia://` URL scheme.
final class RootApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.root`.
  RootApi(CheckRunner runner, RootRepository repository)
    : super(CheckType.root, runner, repository.rootReport);
}
