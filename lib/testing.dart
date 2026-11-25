/// Test support: fake the platform side of `device_safety_info` in widget and unit tests.
///
/// ```dart
/// class FakeRoot extends Fake implements RootHostApi {
///   @override
///   Future<CheckReportMsg> rootCheck() async => CheckReportMsg(
///     signals: [SignalMsg(id: 'root.su_executable', level: SignalLevelMsg.high)],
///     supported: true,
///   );
/// }
///
/// DeviceSafety.forTesting(
///   platform: DeviceSafetyPlatform(root: FakeRoot(), ffi: const FakeNativeChecks()),
/// );
/// ```
library;

export 'src/core/platform/device_safety_platform.dart';
export 'src/core/platform/generated/device_safety_api.g.dart';
export 'src/core/platform/native_checks_ffi.dart'
    show NativeChecks, NativeChecksSource;

import 'src/core/platform/native_checks_ffi.dart';

/// A [NativeChecksSource] that reports the given [bits] (`DSI_*` flags), or nothing.
final class FakeNativeChecks implements NativeChecksSource {
  /// Creates the fake.
  const FakeNativeChecks([this.bits = 0, this.supported = true]);

  /// Bits to report.
  final int bits;

  /// Whether the native library is "available".
  final bool supported;

  @override
  Future<NativeChecks> collect({int mask = NativeChecksFfi.allMask}) async =>
      supported ? NativeChecks(bits & mask) : NativeChecks.unavailable;
}
