import 'package:device_safety_info/src/core/platform/generated/dsi_bindings.g.dart'
    as dsi;
import 'package:device_safety_info/src/core/platform/native_checks_ffi.dart';
import 'package:device_safety_info/src/core/result/risk_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'collect never throws on the host (asset may or may not be built)',
    () async {
      final r = await const NativeChecksFfi().collect();
      // On a desktop host the C checks are compiled but none apply.
      expect(r.bits, 0);
    },
  );

  test('bit decoding', () {
    const all = NativeChecks(dsi.DSI_ALL_CHECKS);
    expect(all.rootSignals.map((s) => s.id), [
      'root.native_files',
      'root.native_su_present',
    ]);
    expect(all.rootSignals.first.level, RiskLevel.high);
    expect(all.rootSignals.last.level, RiskLevel.low);
    expect(all.hookingSignals.map((s) => s.id), [
      'hooking.frida_maps',
      'hooking.frida_port',
      'hooking.dyld_injection',
    ]);
    expect(all.debuggerSignals.single.id, 'debugger.traced');
    expect(all.debuggerSignals.single.source, SignalSource.ffi);
    expect(NativeChecks.unavailable.supported, isFalse);
    expect(NativeChecks.unavailable.rootSignals, isEmpty);
  });

  test('masks partition the checks', () {
    expect(
      NativeChecksFfi.rootMask |
          NativeChecksFfi.hookingMask |
          NativeChecksFfi.debuggerMask,
      NativeChecksFfi.allMask,
    );
  });
}
