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
              case 'copyToClipboard':
              case 'clearClipboard':
              case 'blockTouchesWhenObscured':
                return null;
              case 'isPackageInstalled':
                return false;
              case 'getEnabledAccessibilityServices':
                return <String>[];
              case 'getPlayProtectStatus':
                return 0;
              case 'getEnabledNotificationListeners':
                return <String>[];
              case 'isUnknownSourcesEnabled':
                return false;
              case 'isCallScreeningRoleAvailable':
              case 'isCallScreeningRoleHeldByThisApp':
                return false;
              case 'openCallScreeningRoleSettings':
                return null;
              case 'isCallActive':
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

    test('copyToClipboard invokes the channel with the given text', () async {
      await DeviceSafetyInfo.copyToClipboard('secret', sensitive: true);
      expect(calls.single.method, 'copyToClipboard');
      expect(calls.single.arguments['text'], 'secret');
      expect(calls.single.arguments['sensitive'], true);
      expect(calls.single.arguments['autoClearMillis'], isNull);
    });

    test('copyToClipboard passes autoClear as milliseconds', () async {
      await DeviceSafetyInfo.copyToClipboard(
        'otp',
        autoClear: const Duration(seconds: 30),
      );
      expect(calls.single.arguments['autoClearMillis'], 30000);
    });

    test('clearClipboard invokes the channel', () async {
      await DeviceSafetyInfo.clearClipboard();
      expect(calls.single.method, 'clearClipboard');
    });

    // These getters are Android-gated (Platform.isAndroid), so on the host platform this test
    // suite runs under, they resolve to their safe default without ever reaching the mocked
    // channel — this exercises exactly the behavior a non-Android platform (iOS) sees.
    test('enabledAccessibilityServices is empty off-Android', () async {
      expect(await DeviceSafetyInfo.enabledAccessibilityServices, isEmpty);
    });

    test('isAnyAccessibilityServiceEnabled is false off-Android', () async {
      expect(await DeviceSafetyInfo.isAnyAccessibilityServiceEnabled, false);
    });

    test('playProtectStatus is unknown off-Android', () async {
      expect(
        await DeviceSafetyInfo.playProtectStatus,
        PlayProtectStatus.unknown,
      );
    });

    test('enabledNotificationListeners is empty off-Android', () async {
      expect(await DeviceSafetyInfo.enabledNotificationListeners, isEmpty);
    });

    test('isAnyNotificationListenerEnabled is false off-Android', () async {
      expect(await DeviceSafetyInfo.isAnyNotificationListenerEnabled, false);
    });

    test('isUnknownSourcesEnabled is false off-Android', () async {
      expect(await DeviceSafetyInfo.isUnknownSourcesEnabled, false);
    });

    test('isCallScreeningRoleAvailable is false off-Android', () async {
      expect(await DeviceSafetyInfo.isCallScreeningRoleAvailable, false);
    });

    test('isCallScreeningRoleHeldByThisApp is false off-Android', () async {
      expect(await DeviceSafetyInfo.isCallScreeningRoleHeldByThisApp, false);
    });

    test('isCallActive returns false from mock', () async {
      expect(await DeviceSafetyInfo.isCallActive, false);
    });

    test(
      'MalwarePackageDetector.isPackageInstalled is false off-Android',
      () async {
        expect(
          await MalwarePackageDetector.isPackageInstalled('com.example.app'),
          false,
        );
      },
    );
  });

  group('RiskSummary.evaluate', () {
    const channel = MethodChannel('device_safety_info');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> mockChecks({
      bool rooted = false,
      bool hooked = false,
      bool debugger = false,
      bool screenCaptured = false,
      bool vpn = false,
      bool screenLock = true,
    }) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'isRootedDevice':
                return rooted;
              case 'isHooked':
                return hooked;
              case 'isDebuggerAttached':
                return debugger;
              case 'isScreenCaptured':
                return screenCaptured;
              case 'isVPNCheck':
                return vpn;
              case 'isScreenLock':
                return screenLock;
              default:
                return null;
            }
          });
    }

    test('returns no flags when every check is clean', () async {
      await mockChecks();
      expect(await RiskSummary.evaluate(), isEmpty);
    });

    test('flags a rooted device and a missing screen lock', () async {
      await mockChecks(rooted: true, screenLock: false);
      final flags = await RiskSummary.evaluate();
      expect(flags.map((f) => f.id).toSet(), {'rooted', 'no_screen_lock'});
    });

    test(
      'flags hooking, debugger, screen capture, and VPN independently',
      () async {
        await mockChecks(
          hooked: true,
          debugger: true,
          screenCaptured: true,
          vpn: true,
        );
        final flags = await RiskSummary.evaluate();
        expect(flags.map((f) => f.id).toSet(), {
          'hooked',
          'debugger',
          'screen_captured',
          'vpn',
        });
      },
    );
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
      expect(
        VersionStatus(localVersion: null, storeVersion: '1.0.0').canUpdate,
        false,
      );
      expect(
        VersionStatus(localVersion: '1.0.0', storeVersion: null).canUpdate,
        false,
      );
      expect(
        VersionStatus(localVersion: null, storeVersion: null).canUpdate,
        false,
      );
    });

    test('handles store having more version segments than local', () {
      final s = VersionStatus(localVersion: '1.0', storeVersion: '1.0.1');
      expect(s.canUpdate, true);
    });
  });

  group('CallActivityEvent.fromMap', () {
    test('parses a started simCall event', () {
      final event = CallActivityEvent.fromMap({
        'source': 'simCall',
        'state': 'started',
        'timestamp': 1700000000000,
      });
      expect(event.source, CallActivitySource.simCall);
      expect(event.state, CallActivityState.started);
      expect(
        event.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('parses an ended voipCall event', () {
      final event = CallActivityEvent.fromMap({
        'source': 'voipCall',
        'state': 'ended',
        'timestamp': 1700000001000,
      });
      expect(event.source, CallActivitySource.voipCall);
      expect(event.state, CallActivityState.ended);
    });

    test('unrecognized source falls back to unknown', () {
      final event = CallActivityEvent.fromMap({
        'source': 'somethingNew',
        'state': 'started',
        'timestamp': 1700000000000,
      });
      expect(event.source, CallActivitySource.unknown);
    });
  });

  group('IOCDomainBlocker', () {
    setUp(() => IOCDomainBlocker.updateBlocklist([]));

    test('isBlocked is false with an empty blocklist', () {
      expect(IOCDomainBlocker.isBlocked('evil.com'), false);
    });

    test('exact-match entries block only that domain', () {
      IOCDomainBlocker.updateBlocklist(['evil.com']);
      expect(IOCDomainBlocker.isBlocked('evil.com'), true);
      expect(IOCDomainBlocker.isBlocked('sub.evil.com'), false);
      expect(IOCDomainBlocker.isBlocked('notevil.com'), false);
    });

    test('wildcard entries block subdomains but not the bare domain', () {
      IOCDomainBlocker.updateBlocklist(['*.evil.com']);
      expect(IOCDomainBlocker.isBlocked('a.evil.com'), true);
      expect(IOCDomainBlocker.isBlocked('a.b.evil.com'), true);
      expect(IOCDomainBlocker.isBlocked('evil.com'), false);
    });

    test('matching is case-insensitive', () {
      IOCDomainBlocker.updateBlocklist(['Evil.COM']);
      expect(IOCDomainBlocker.isBlocked('evil.com'), true);
      expect(IOCDomainBlocker.isBlocked('EVIL.com'), true);
    });

    test('updateBlocklist replaces the previous list, not merges', () {
      IOCDomainBlocker.updateBlocklist(['evil.com']);
      IOCDomainBlocker.updateBlocklist(['other.com']);
      expect(IOCDomainBlocker.isBlocked('evil.com'), false);
      expect(IOCDomainBlocker.isBlocked('other.com'), true);
    });

    test('blank entries are ignored', () {
      IOCDomainBlocker.updateBlocklist(['', '  ', 'evil.com']);
      expect(IOCDomainBlocker.isBlocked('evil.com'), true);
    });
  });
}
