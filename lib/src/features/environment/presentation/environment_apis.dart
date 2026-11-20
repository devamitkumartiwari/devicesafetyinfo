import '../../../core/config/device_safety_config.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/environment_repository.dart';

Future<CheckReport> _android(
  EnvironmentRepository repository,
  CheckType type,
) async =>
    PlatformGuard.isAndroid ? repository.report(type) : CheckReport.unsupported;

/// Remote-control apps, the main tool of "support call" scams (Android).
///
/// High risk: `remote_access.control_service:<package>`, an enabled accessibility service of a
/// remote-control app (AnyDesk, TeamViewer QuickSupport, RustDesk, AirDroid, ...), which lets the
/// remote side tap and type. Low risk: `remote_access.app_installed:<package>`. Allowlist tools
/// your organization uses with `DeviceSafetyConfig.remoteAccessAllowlist`. iOS: unsupported (use
/// the screen-capture check for screen sharing).
final class RemoteAccessApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.remoteAccess`.
  RemoteAccessApi(
    CheckRunner runner,
    EnvironmentRepository repository,
    DeviceSafetyConfig Function() config,
  ) : super(
        CheckType.remoteAccess,
        runner,
        () async => withoutAllowlistedPackages(
          await _android(repository, CheckType.remoteAccess),
          config().remoteAccessAllowlist,
        ),
      );
}

/// GPS spoofing (Android).
///
/// High risk: `location.mock_app_selected:<package>` (chosen as the mock location app in
/// developer options) and `location.mock_fix` (the last known location is mock; checked only if
/// the app already holds a location permission). Low risk:
/// `location.mock_app_installed:<package>`. iOS: unsupported.
final class LocationSpoofingApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.locationSpoofing`.
  LocationSpoofingApi(CheckRunner runner, EnvironmentRepository repository)
    : super(
        CheckType.locationSpoofing,
        runner,
        () => _android(repository, CheckType.locationSpoofing),
      );
}

/// The app running in a cloned or dual-app space (Android).
///
/// High risk: `clone.virtual_container:<host>` (the app runs inside another app, such as
/// Parallel Space or VirtualXposed). Low risk: `clone.secondary_user` (Dual Messenger, Second
/// Space, Secure Folder), `clone.work_profile`, `clone.cloner_installed:<package>`. iOS:
/// unsupported.
final class AppCloningApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.appCloning`.
  AppCloningApi(CheckRunner runner, EnvironmentRepository repository)
    : super(
        CheckType.appCloning,
        runner,
        () => _android(repository, CheckType.appCloning),
      );
}

/// User-installed CA certificates, which let proxies decrypt HTTPS (Android).
///
/// High risk: `mitm.user_ca_with_proxy` (a user CA while a VPN or proxy routes the traffic).
/// Low risk: `mitm.user_ca:<name>`. Pair it with `DeviceSafety.pinning`, which stops
/// interception of your own API traffic regardless. iOS: unsupported.
final class MitmApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.mitm`.
  MitmApi(CheckRunner runner, EnvironmentRepository repository)
    : super(CheckType.mitm, runner, () => _android(repository, CheckType.mitm));
}

/// A third-party default keyboard, which sees everything typed (Android).
///
/// Low risk: `keyboard.third_party:<package>`; high risk when the same app also runs an enabled
/// accessibility service. Preinstalled keyboards, Gboard, SwiftKey and
/// `DeviceSafetyConfig.keyboardAllowlist` are not reported. iOS: the check is unsupported, but
/// [blockCustomKeyboards] refuses third-party keyboards (see its docs for the AppDelegate line).
/// For individual fields, `SecureInputConfig` turns off suggestions and learning.
final class KeyboardApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.keyboard`.
  KeyboardApi(
    CheckRunner runner,
    EnvironmentRepository repository,
    DeviceSafetyConfig Function() config,
  ) : _repository = repository,
      super(
        CheckType.keyboard,
        runner,
        () async => withoutAllowlistedPackages(
          await _android(repository, CheckType.keyboard),
          config().keyboardAllowlist,
        ),
      );

  final EnvironmentRepository _repository;

  /// (iOS) Refuses third-party keyboard extensions in this app when [block] is `true`; the
  /// system keyboard is used instead. The setting is stored and applies from the next keyboard
  /// shown. Requires this in your `AppDelegate`:
  ///
  /// ```swift
  /// override func application(
  ///   _ application: UIApplication,
  ///   shouldAllowExtensionPointIdentifier id: UIApplication.ExtensionPointIdentifier
  /// ) -> Bool {
  ///   DeviceSafetyInfoPlugin.shouldAllowExtension(id)
  /// }
  /// ```
  ///
  /// No-op on other platforms.
  Future<void> blockCustomKeyboards(bool block) async {
    if (!PlatformGuard.isIOS) return;
    await _repository.setBlockCustomKeyboards(block);
  }
}
