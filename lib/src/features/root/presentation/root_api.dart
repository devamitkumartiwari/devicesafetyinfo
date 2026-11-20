import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/root_repository.dart';

/// Root (Android) and jailbreak (iOS) detection.
///
/// High-risk signals: an executable `su`; Magisk, KernelSU, APatch or Superuser files, mounts
/// or manager apps; insecure build properties (`ro.secure=0`, adbd as root, SELinux
/// permissive); a failed IOSSecuritySuite jailbreak check; jailbreak files found by the native
/// C check. Low-risk (strict policy only): busybox, a non-executable `su`, `test-keys`, an
/// unlocked bootloader, a root-cloaking app, a jailbreak-app URL scheme. See the README's
/// signal catalogue for the full list.
final class RootApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.root`.
  RootApi(CheckRunner runner, RootRepository repository)
    : super(CheckType.root, runner, repository.rootReport);
}
