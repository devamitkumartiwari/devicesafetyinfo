import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_safety_info/device_safety_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RiskCheckResult.fromMap', () {
    test('parses a high-risk result', () {
      final r = RiskCheckResult.fromMap({
        'level': 'high',
        'highRiskSignals': ['path:/system/bin/su'],
        'lowRiskSignals': ['prop:ro.boot.verifiedbootstate=orange'],
      });
      expect(r.level, RiskLevel.high);
      expect(r.isHighRisk, true);
      expect(r.signals, [
        'path:/system/bin/su',
        'prop:ro.boot.verifiedbootstate=orange',
      ]);
    });

    test('never reports a lower level than the signals justify', () {
      final r = RiskCheckResult.fromMap({
        'level': 'none',
        'highRiskSignals': ['file:/data/adb/magisk'],
      });
      expect(r.level, RiskLevel.high);

      final low = RiskCheckResult.fromMap({
        'level': 'none',
        'lowRiskSignals': ['path:/system/xbin/busybox'],
      });
      expect(low.level, RiskLevel.low);
    });

    test('tolerates missing or malformed fields', () {
      final r = RiskCheckResult.fromMap({
        'level': 42,
        'highRiskSignals': 'oops',
      });
      expect(r.level, RiskLevel.none);
      expect(r.signals, isEmpty);
    });
  });

  group('RiskCheckResult.isDetected', () {
    const none = RiskCheckResult.clean;
    const low = RiskCheckResult(level: RiskLevel.low, lowRiskSignals: ['b']);
    const high = RiskCheckResult(level: RiskLevel.high, highRiskSignals: ['s']);

    test('standard policy counts only high', () {
      expect(none.isDetected(), false);
      expect(low.isDetected(), false);
      expect(high.isDetected(), true);
      expect(low.isDetected(policy: RiskPolicy.standard), false);
    });

    test('strict policy counts low and high', () {
      expect(none.isDetected(policy: RiskPolicy.strict), false);
      expect(low.isDetected(policy: RiskPolicy.strict), true);
      expect(high.isDetected(policy: RiskPolicy.strict), true);
    });
  });

  group('DeviceSafetyInfo.isRooted', () {
    const channel = MethodChannel('device_safety_info');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'rootCheck') {
              return {
                'level': 'low',
                'lowRiskSignals': ['prop:ro.boot.verifiedbootstate=orange'],
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'a low-risk device is not rooted under the default (standard) policy',
      () async {
        expect(await DeviceSafetyInfo.isRooted(), false);
      },
    );

    test('a low-risk device is rooted under the strict policy', () async {
      expect(await DeviceSafetyInfo.isRooted(policy: RiskPolicy.strict), true);
    });
  });

  group('RiskCheckResult.withSignal', () {
    test('raises the level and does not duplicate signals', () {
      final r = RiskCheckResult.clean
          .withSignal('native:su_not_executable', RiskLevel.low)
          .withSignal('native:root_files', RiskLevel.high)
          .withSignal('native:root_files', RiskLevel.high);
      expect(r.level, RiskLevel.high);
      expect(r.highRiskSignals, ['native:root_files']);
      expect(r.lowRiskSignals, ['native:su_not_executable']);
    });

    test('a low signal never lowers a high level', () {
      const r = RiskCheckResult(level: RiskLevel.high, highRiskSignals: ['x']);
      expect(r.withSignal('y', RiskLevel.low).level, RiskLevel.high);
    });
  });

  group('DeviceSafetyInfo.rootCheck fallback', () {
    const channel = MethodChannel('device_safety_info');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'falls back to isRootedDevice when rootCheck is not implemented',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'isRootedDevice') return true;
              throw MissingPluginException();
            });
        final r = await DeviceSafetyInfo.rootCheck;
        expect(r.level, RiskLevel.high);
        expect(r.highRiskSignals, ['platform:isRootedDevice']);
      },
    );

    test('returns a clean result on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'ERR');
          });
      expect((await DeviceSafetyInfo.rootCheck).level, RiskLevel.none);
    });
  });

  group('DeviceSafetyInfo emulator checks', () {
    const channel = MethodChannel('device_safety_info');

    void mock(Map<String, Object?> emulatorCheck) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'emulatorCheck') return emulatorCheck;
            if (call.method == 'isRealDevice') return true;
            return null;
          });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a real budget phone reporting "unknown" is low-risk, not an emulator by default', () async {
      mock({
        'level': 'low',
        'lowRiskSignals': ['manufacturer:unknown'],
      });
      final r = await DeviceSafetyInfo.emulatorCheck;
      expect(r.level, RiskLevel.low);
      expect(r.lowRiskSignals, ['manufacturer:unknown']);
      expect(await DeviceSafetyInfo.isEmulator(), false);
      expect(
        await DeviceSafetyInfo.isEmulator(policy: RiskPolicy.strict),
        true,
      );
    });

    test('emulator hardware is high-risk under both policies', () async {
      mock({
        'level': 'high',
        'highRiskSignals': ['hardware:ranchu', 'prop:ro.kernel.qemu=1'],
      });
      expect(await DeviceSafetyInfo.isEmulator(), true);
      expect(
        await DeviceSafetyInfo.isEmulator(policy: RiskPolicy.strict),
        true,
      );
    });

    test(
      'falls back to isRealDevice when emulatorCheck is not implemented',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'isRealDevice') return false;
              throw MissingPluginException();
            });
        final r = await DeviceSafetyInfo.emulatorCheck;
        expect(r.level, RiskLevel.high);
        expect(r.highRiskSignals, ['platform:isRealDevice']);
      },
    );
  });
}
