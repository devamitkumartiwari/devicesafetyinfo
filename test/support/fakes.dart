// Test fakes; streams live for the whole test process.
// ignore_for_file: close_sinks

import 'dart:async';

import 'package:device_safety_info/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SignalMsg high(String id) => SignalMsg(id: id, level: SignalLevelMsg.high);
SignalMsg low(String id) => SignalMsg(id: id, level: SignalLevelMsg.low);
CheckReportMsg report(List<SignalMsg> signals, {bool supported = true}) =>
    CheckReportMsg(signals: signals, supported: supported);

/// Counts calls and returns configurable reports.
class FakeRootApi extends Fake implements RootHostApi {
  CheckReportMsg root = report([]);
  CheckReportMsg emulator = report([]);
  Object? error;
  int rootCalls = 0;

  @override
  Future<CheckReportMsg> rootCheck() async {
    rootCalls++;
    if (error != null) throw error!;
    return root;
  }

  @override
  Future<CheckReportMsg> emulatorCheck() async => emulator;
}

class FakeHookingApi extends Fake implements HookingHostApi {
  CheckReportMsg hook = report([]);
  CheckReportMsg debugger = report([]);
  Object? error;
  int hookCalls = 0;

  @override
  Future<CheckReportMsg> hookCheck() async {
    hookCalls++;
    if (error != null) throw error!;
    return hook;
  }

  @override
  Future<CheckReportMsg> debuggerCheck() async => debugger;
}

class FakePostureApi extends Fake implements PostureHostApi {
  final Map<String, CheckReportMsg> reports = {};
  List<AccessibilityServiceMsg> accessibility = [];
  List<NotificationListenerMsg> listeners = [];

  Future<CheckReportMsg> _r(String id) async => reports[id] ?? report([]);

  @override
  Future<CheckReportMsg> developerMode() => _r('developerMode');
  @override
  Future<CheckReportMsg> screenLock() => _r('screenLock');
  @override
  Future<CheckReportMsg> storeInstall() => _r('storeInstall');
  @override
  Future<CheckReportMsg> externalStorage() => _r('externalStorage');
  @override
  Future<CheckReportMsg> unknownSources() => _r('unknownSources');
  @override
  Future<CheckReportMsg> playProtect() => _r('playProtect');
  @override
  Future<List<AccessibilityServiceMsg>> enabledAccessibilityServices() async =>
      accessibility;
  @override
  Future<List<NotificationListenerMsg>> enabledNotificationListeners() async =>
      listeners;
}

class FakeBatchApi extends Fake implements BatchHostApi {
  BatchResultMsg result = BatchResultMsg(
    reports: {},
    accessibilityServices: [],
    notificationListeners: [],
    installedPackages: [],
    failedLists: [],
  );
  final List<BatchRequestMsg> requests = [];
  Object? error;

  @override
  Future<BatchResultMsg> runChecks(BatchRequestMsg request) async {
    requests.add(request);
    if (error != null) throw error!;
    return result;
  }
}

class FakeVpnApi extends Fake implements VpnHostApi {
  CheckReportMsg vpn = report([]);
  int calls = 0;

  @override
  Future<CheckReportMsg> vpnCheck() async {
    calls++;
    return vpn;
  }
}

class FakeMalwareApi extends Fake implements MalwareHostApi {
  Set<String> installed = {};

  @override
  Future<List<String>> installedOf(List<String> packages) async =>
      packages.where(installed.contains).toList();
}

class FakeScreenApi extends Fake implements ScreenProtectionHostApi {
  bool blocked = false;
  OverlayConfigMsg? overlay;
  CheckReportMsg capture = report([]);
  PlatformException? error;

  @override
  Future<void> blockScreenshots(bool block) async {
    if (error != null) throw error!;
    blocked = block;
  }

  @override
  Future<bool> isScreenshotBlocked() async => blocked;

  @override
  Future<void> setOverlayMode(OverlayConfigMsg config) async =>
      overlay = config;

  @override
  Future<void> clearOverlayMode() async => overlay = null;

  @override
  Future<CheckReportMsg> screenCaptureCheck() async => capture;

  @override
  Future<bool> isRecordingDetectionSupported() async => true;
}

class FakeAppSwitcherApi extends Fake implements AppSwitcherHostApi {
  int? argb;
  bool? hidden;

  @override
  Future<void> setRecentsOverlay(int argb) async => this.argb = argb;
  @override
  Future<void> clearRecentsOverlay() async => argb = null;
  @override
  Future<void> hideFromRecents(bool hide) async {
    throw PlatformException(code: 'UNSUPPORTED', message: 'iOS');
  }
}

class FakeClipboardApi extends Fake implements ClipboardHostApi {
  String? text;
  bool? sensitive;
  int? clearAfterMs;

  @override
  Future<void> copySecure(
    String text,
    bool sensitive,
    int? clearAfterMs,
  ) async {
    this.text = text;
    this.sensitive = sensitive;
    this.clearAfterMs = clearAfterMs;
  }

  @override
  Future<void> clear() async => text = null;
}

class FakeOverlayApi extends Fake implements OverlayAttackHostApi {
  bool? block;

  @override
  Future<void> blockTouchesWhenObscured(bool block) async => this.block = block;
}

class FakeCallApi extends Fake implements CallHostApi {
  @override
  Future<bool> isCallActive() async => true;
  @override
  Future<bool> isScreeningRoleAvailable() async => true;
  @override
  Future<bool> isScreeningRoleHeld() async => false;
  @override
  Future<void> openScreeningRoleSettings() async {
    throw PlatformException(code: 'NO_ACTIVITY');
  }
}

class FakeAppInfoApi extends Fake implements AppInfoHostApi {
  SigningInfoMsg signing = SigningInfoMsg(
    certificateSha256: ['ab' * 32],
    hasProvisioningProfile: false,
  );

  @override
  Future<SigningInfoMsg> signingInfo() async => signing;

  @override
  Future<AppInfoMsg> packageInfo() async => AppInfoMsg(
    packageName: 'com.example.app',
    version: '1.2.3+4',
    buildNumber: '4',
  );
}

class FakeIntegrityApi extends Fake implements IntegrityHostApi {
  @override
  Future<bool> isPlayIntegrityAvailable() async => true;
  @override
  Future<void> preparePlayIntegrity(int cloudProjectNumber) async {}
  @override
  Future<String> requestPlayIntegrityToken(String requestHash) async {
    throw PlatformException(code: 'NOT_PREPARED', message: 'prepare first');
  }

  @override
  Future<bool> isAppAttestSupported() async => true;
  @override
  Future<String> generateAppAttestKey() async => 'key-1';
  @override
  Future<String> attestAppAttestKey(String keyId, String challenge) async =>
      'att:$keyId:$challenge';
  @override
  Future<String> generateAppAttestAssertion(
    String keyId,
    String clientData,
  ) async {
    throw PlatformException(code: 'INVALID_KEY');
  }

  @override
  Future<bool> isDeviceCheckSupported() async => false;
  @override
  Future<String> generateDeviceCheckToken() async => 'dc';
}

class FakeEnvironmentApi extends Fake implements EnvironmentHostApi {
  CheckReportMsg remote = report([]);
  CheckReportMsg location = report([]);
  CheckReportMsg cloning = report([]);
  CheckReportMsg mitmReport = report([]);

  @override
  Future<CheckReportMsg> remoteAccess() async => remote;
  @override
  Future<CheckReportMsg> locationSpoofing() async => location;
  @override
  Future<CheckReportMsg> appCloning() async => cloning;
  @override
  Future<CheckReportMsg> mitm() async => mitmReport;

  CheckReportMsg keyboardReport = report([]);
  bool? blockedKeyboards;

  @override
  Future<CheckReportMsg> keyboard() async => keyboardReport;
  @override
  Future<void> setBlockCustomKeyboards(bool block) async =>
      blockedKeyboards = block;
}

/// In-memory keys: "signatures" are the alias bytes followed by the data.
class FakeDeviceKeyApi extends Fake implements DeviceKeyHostApi {
  final Map<String, DeviceKeyInfoMsg> keys = {};
  Uint8List? lastChallenge;
  bool? lastPreferStrongBox;

  @override
  Future<DeviceKeyInfoMsg> create(
    String alias,
    Uint8List? challenge,
    bool preferStrongBox,
  ) async {
    lastChallenge = challenge;
    lastPreferStrongBox = preferStrongBox;
    return keys[alias] = DeviceKeyInfoMsg(
      publicKey: 'AQID',
      securityLevel: preferStrongBox
          ? KeySecurityLevelMsg.strongBox
          : KeySecurityLevelMsg.tee,
      attestationChain: challenge != null ? ['BAUG', 'BwgJ'] : [],
    );
  }

  @override
  Future<DeviceKeyInfoMsg?> info(String alias) async => keys[alias];

  @override
  Future<Uint8List> sign(String alias, Uint8List data) async {
    if (!keys.containsKey(alias)) {
      throw PlatformException(code: 'KEY_MISSING');
    }
    return Uint8List.fromList([...alias.codeUnits, ...data]);
  }

  @override
  Future<bool> exists(String alias) async => keys.containsKey(alias);

  @override
  Future<void> delete(String alias) async => keys.remove(alias);
}

class FakeBiometricApi extends Fake implements BiometricHostApi {
  bool available = true;
  final Map<String, BiometricKeyStateMsg> states = {};
  PlatformException? approveError;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceKeyInfoMsg> enroll(String alias) async {
    if (!available) throw PlatformException(code: 'NOT_ENROLLED');
    states[alias] = BiometricKeyStateMsg.valid;
    return DeviceKeyInfoMsg(
      publicKey: 'AQID',
      securityLevel: KeySecurityLevelMsg.tee,
      attestationChain: [],
    );
  }

  @override
  Future<Uint8List> approve(
    String alias,
    Uint8List payload,
    String title,
    String reason,
  ) async {
    if (approveError case final e?) throw e;
    if (states[alias] == BiometricKeyStateMsg.invalidated) {
      throw PlatformException(code: 'ENROLLMENT_CHANGED');
    }
    return Uint8List.fromList(payload.reversed.toList());
  }

  @override
  Future<BiometricKeyStateMsg> keyState(String alias) async =>
      states[alias] ?? BiometricKeyStateMsg.missing;

  @override
  Future<void> delete(String alias) async => states.remove(alias);
}

/// Live streams driven by the test.
class FakeEvents implements PlatformEvents {
  final screenshotsCtl = StreamController<int>.broadcast();
  final captureCtl = StreamController<bool>.broadcast();
  final recordingCtl = StreamController<bool>.broadcast();
  final overlayCtl = StreamController<int>.broadcast();
  final clipboardCtl = StreamController<int>.broadcast();
  final vpnCtl = StreamController<bool>.broadcast();
  final callCtl = StreamController<CallEventMsg>.broadcast();

  @override
  Stream<int> get screenshots => screenshotsCtl.stream;
  @override
  Stream<bool> get captureChanges => captureCtl.stream;
  @override
  Stream<bool> get recordingChanges => recordingCtl.stream;
  @override
  Stream<int> get overlayAttacks => overlayCtl.stream;
  @override
  Stream<int> get clipboardChanges => clipboardCtl.stream;
  @override
  Stream<bool> get vpnChanges => vpnCtl.stream;
  @override
  Stream<CallEventMsg> get callActivity => callCtl.stream;
}

/// Every fake, wired into one platform bundle.
class Fakes {
  final root = FakeRootApi();
  final hooking = FakeHookingApi();
  final posture = FakePostureApi();
  final batch = FakeBatchApi();
  final vpn = FakeVpnApi();
  final malware = FakeMalwareApi();
  final screen = FakeScreenApi();
  final appSwitcher = FakeAppSwitcherApi();
  final clipboard = FakeClipboardApi();
  final overlay = FakeOverlayApi();
  final call = FakeCallApi();
  final appInfo = FakeAppInfoApi();
  final integrity = FakeIntegrityApi();
  final environment = FakeEnvironmentApi();
  final deviceKey = FakeDeviceKeyApi();
  final biometric = FakeBiometricApi();
  final events = FakeEvents();
  FakeNativeChecks ffi = const FakeNativeChecks();

  DeviceSafetyPlatform platform() => DeviceSafetyPlatform(
    root: root,
    hooking: hooking,
    posture: posture,
    batch: batch,
    vpn: vpn,
    malware: malware,
    screen: screen,
    appSwitcher: appSwitcher,
    clipboard: clipboard,
    overlayAttack: overlay,
    call: call,
    appInfo: appInfo,
    integrity: integrity,
    environment: environment,
    deviceKey: deviceKey,
    biometric: biometric,
    events: events,
    ffi: ffi,
  );
}
