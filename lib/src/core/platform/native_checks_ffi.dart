import 'dart:isolate';

import '../result/risk_signal.dart';
import 'generated/dsi_bindings.g.dart' as dsi;

/// What the native C checks found. [supported] is `false` when the native library couldn't be
/// used (not built for this platform, ABI mismatch); the signal lists are then empty.
final class NativeChecks {
  /// Creates a result from the raw bit mask.
  const NativeChecks(this.bits, {this.supported = true});

  /// The native library isn't available.
  static const NativeChecks unavailable = NativeChecks(0, supported: false);

  /// Bits of the checks that fired (`DSI_*` in `src/dsi.h`).
  final int bits;

  /// Whether the native library ran.
  final bool supported;

  bool _has(int bit) => bits & bit != 0;

  /// Root indicators.
  List<RiskSignal> get rootSignals => [
    if (_has(dsi.DSI_ROOT_FILES_HIGH))
      const RiskSignal('root.native_files', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_ROOT_FILES_LOW))
      const RiskSignal('root.native_su_present', RiskLevel.low, source: .ffi),
    if (_has(dsi.DSI_ROOT_MOUNTS))
      const RiskSignal('root.native_mounts', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_JB_FILES))
      const RiskSignal(
        'root.native_jailbreak_files',
        RiskLevel.high,
        source: .ffi,
      ),
  ];

  /// Hooking indicators.
  List<RiskSignal> get hookingSignals => [
    if (_has(dsi.DSI_FRIDA_MAPS))
      const RiskSignal('hooking.frida_maps', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_FRIDA_PORT))
      const RiskSignal('hooking.frida_port', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_DYLD_INJECTION))
      const RiskSignal('hooking.dyld_injection', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_FRIDA_THREADS))
      const RiskSignal('hooking.frida_threads', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_FRIDA_FDS))
      const RiskSignal('hooking.frida_fds', RiskLevel.high, source: .ffi),
    if (_has(dsi.DSI_TEXT_PATCHED))
      const RiskSignal('hooking.text_patched', RiskLevel.high, source: .ffi),
  ];

  /// Debugger indicators.
  List<RiskSignal> get debuggerSignals => [
    if (_has(dsi.DSI_DEBUGGER))
      const RiskSignal('debugger.traced', RiskLevel.high, source: .ffi),
  ];
}

/// Source of native check results. An interface so tests can substitute a fake.
abstract interface class NativeChecksSource {
  /// Runs the checks in [mask] (`DSI_*` bits) off the calling isolate.
  Future<NativeChecks> collect({int mask});
}

/// Calls `dsi_collect_signals` from `src/dsi.c` through FFI.
final class NativeChecksFfi implements NativeChecksSource {
  /// Creates the source.
  const NativeChecksFfi();

  /// Every check bit.
  static const int allMask = dsi.DSI_ALL_CHECKS;

  /// Mask for root checks.
  static const int rootMask =
      dsi.DSI_ROOT_FILES_HIGH |
      dsi.DSI_ROOT_FILES_LOW |
      dsi.DSI_ROOT_MOUNTS |
      dsi.DSI_JB_FILES;

  /// Mask for hooking checks.
  static const int hookingMask =
      dsi.DSI_FRIDA_MAPS |
      dsi.DSI_FRIDA_PORT |
      dsi.DSI_DYLD_INJECTION |
      dsi.DSI_FRIDA_THREADS |
      dsi.DSI_FRIDA_FDS |
      dsi.DSI_TEXT_PATCHED;

  /// Mask for the debugger check.
  static const int debuggerMask = dsi.DSI_DEBUGGER;

  @override
  Future<NativeChecks> collect({int mask = allMask}) =>
      // The port probe can block for ~100 ms and the libc comparison reads ~1 MB, so never run on
      // the caller's isolate.
      Isolate.run(() => _collectSync(mask));

  static NativeChecks _collectSync(int mask) {
    try {
      if (dsi.dsi_abi_version() != dsi.DSI_ABI_VERSION) {
        return NativeChecks.unavailable;
      }
      return NativeChecks(dsi.dsi_collect_signals(mask) & mask);
    } on ArgumentError {
      // The native asset isn't bundled for this platform (e.g. host-side unit tests).
      return NativeChecks.unavailable;
    } catch (_) {
      return NativeChecks.unavailable;
    }
  }
}
