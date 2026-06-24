import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_safety_info/device_safety_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceSafetyInfo channel', () {
    const channel = MethodChannel('device_safety_info');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'isRootedDevice':
            return false;
          case 'isRealDevice':
            return true;
          case 'isScreenLock':
            return true;
          case 'isVPNCheck':
            return false;
          case 'isInstalledFromStore':
            return false;
          case 'isHooked':
            return false;
          case 'isScreenCaptured':
            return false;
          case 'isDeveloperMode':
            return false;
          case 'isExternalStorage':
            return false;
          case 'isDebuggerAttached':
            return false;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isRootedDevice returns false from mock', () async {
      expect(await DeviceSafetyInfo.isRootedDevice, false);
    });

    test('isRealDevice returns true from mock', () async {
      expect(await DeviceSafetyInfo.isRealDevice, true);
    });

    test('isScreenLock returns true from mock', () async {
      expect(await DeviceSafetyInfo.isScreenLock, true);
    });

    test('isVPNCheck returns false from mock', () async {
      expect(await DeviceSafetyInfo.isVPNCheck, false);
    });

    test('isHooked returns false from mock', () async {
      expect(await DeviceSafetyInfo.isHooked, false);
    });

    test('isDebuggerAttached returns false from mock', () async {
      expect(await DeviceSafetyInfo.isDebuggerAttached, false);
    });
  });

  group('VersionStatus.canUpdate', () {
    test('returns true when store version is higher', () {
      final s = VersionStatus(localVersion: '1.0.0', storeVersion: '1.0.1');
      expect(s.canUpdate, true);
    });

    test('returns false when versions are equal', () {
      final s = VersionStatus(localVersion: '1.2.3', storeVersion: '1.2.3');
      expect(s.canUpdate, false);
    });

    test('returns false when local is ahead', () {
      final s = VersionStatus(localVersion: '2.0.0', storeVersion: '1.9.9');
      expect(s.canUpdate, false);
    });

    test('returns false when either version is null', () {
      expect(VersionStatus(localVersion: null, storeVersion: '1.0.0').canUpdate,
          false);
      expect(VersionStatus(localVersion: '1.0.0', storeVersion: null).canUpdate,
          false);
      expect(VersionStatus(localVersion: null, storeVersion: null).canUpdate,
          false);
    });

    test('handles store having more version segments than local', () {
      final s = VersionStatus(localVersion: '1.0', storeVersion: '1.0.1');
      expect(s.canUpdate, true);
    });
  });
}
