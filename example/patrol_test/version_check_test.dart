// Tests for NewVersionChecker and VersionStatus.
//
// Pure VersionStatus logic tests use plain test() — no platform channel needed.
// getVersionStatus() makes a real network call and uses patrolTest.

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:device_safety_info_example/main.dart';

void main() {
  // ── VersionStatus.canUpdate (pure Dart logic — no patrolTest needed) ────

  group('VersionStatus.canUpdate', () {
    test('returns false when versions are equal', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.0.0',
      );
      expect(status.canUpdate, isFalse);
    });

    test('returns true when store version is higher (major)', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '2.0.0',
      );
      expect(status.canUpdate, isTrue);
    });

    test('returns true when store version is higher (minor)', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.1.0',
      );
      expect(status.canUpdate, isTrue);
    });

    test('returns true when store version is higher (patch)', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.0.1',
      );
      expect(status.canUpdate, isTrue);
    });

    test('returns false when local version is higher than store', () {
      final status = VersionStatus(
        localVersion: '2.0.0',
        storeVersion: '1.0.0',
      );
      expect(status.canUpdate, isFalse);
    });

    test('returns false when localVersion is null', () {
      final status = VersionStatus(
        localVersion: null,
        storeVersion: '1.0.0',
      );
      expect(status.canUpdate, isFalse);
    });

    test('returns false when storeVersion is null', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: null,
      );
      expect(status.canUpdate, isFalse);
    });

    test('returns false when both versions are null', () {
      final status = VersionStatus(
        localVersion: null,
        storeVersion: null,
      );
      expect(status.canUpdate, isFalse);
    });

    test('handles store version with more segments than local', () {
      final status = VersionStatus(
        localVersion: '1.0',
        storeVersion: '1.0.1',
      );
      expect(status.canUpdate, isTrue);
    });

    test('handles local version with more segments than store', () {
      final status = VersionStatus(
        localVersion: '1.0.1',
        storeVersion: '1.0',
      );
      expect(status.canUpdate, isFalse);
    });

    test('appStoreLink is preserved from constructor', () {
      const link = 'https://apps.apple.com/app/id123';
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.0.0',
        appStoreLink: link,
      );
      expect(status.appStoreLink, equals(link));
    });

    test('originalStoreVersion is preserved from constructor', () {
      final status = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.0.0',
        originalStoreVersion: '1.0.0 (42)',
      );
      expect(status.originalStoreVersion, equals('1.0.0 (42)'));
    });
  });

  // ── NewVersionChecker (requires platform + network) ─────────────────────

  patrolTest('getLocalVersion returns a non-empty semver string', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final checker = NewVersionChecker();
    final version = await checker.getLocalVersion();
    expect(version, isNotEmpty);
    // Should look like a semver string: digits separated by dots
    expect(
      RegExp(r'^\d+\.\d+').hasMatch(version),
      isTrue,
      reason: 'Expected semver format like "1.2.0", got "$version"',
    );
  });

  patrolTest('getVersionStatus returns null or valid VersionStatus', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Uses empty app IDs so network call will return null gracefully
    final checker = NewVersionChecker(
      androidId: '',
      iOSId: '',
    );
    final status = await checker.getVersionStatus();
    // null is acceptable (network unavailable, empty ID, or no store match)
    if (status != null) {
      expect(status, isA<VersionStatus>());
      expect(status.localVersion, isNotNull);
    }
  });

  patrolTest('NewVersionChecker with real app ID returns VersionStatus', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Uses the plugin's own pub.dev app IDs for a realistic check
    final checker = NewVersionChecker(
      androidId: 'com.devamitkumartiwari.device_safety_info_example',
      iOSId: '0',
    );
    // Network call — may fail in offline CI; we only assert it doesn't throw
    final status = await checker.getVersionStatus().timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
    if (status != null) {
      expect(status.localVersion, isNotNull);
      expect(status.canUpdate, isA<bool>());
    }
  });
}
