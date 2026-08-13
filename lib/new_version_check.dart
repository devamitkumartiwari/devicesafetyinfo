import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/http/simple_http_get.dart';

/// The result of [NewVersionChecker.getVersionStatus] — the local and store versions, and
/// whether an update is available.
class VersionStatus {
  /// The cleaned local app version (e.g. `1.2.3`).
  final String? localVersion;

  /// The cleaned store version (e.g. `1.2.3`), or the checker's `forceAppVersion` if supplied.
  final String? storeVersion;

  /// The raw store version string before cleaning, or `null` if it couldn't be determined.
  final String? originalStoreVersion;

  /// A link to the app's store listing.
  final String? appStoreLink;

  /// True if [storeVersion] is newer than [localVersion].
  bool get canUpdate {
    if (localVersion == null || storeVersion == null) return false;
    final local = localVersion!.split('.').map(int.parse).toList();
    final store = storeVersion!.split('.').map(int.parse).toList();

    for (var i = 0; i < store.length; i++) {
      if (i >= local.length) return true; // store has more version segments
      if (store[i] > local[i]) return true;
      if (local[i] > store[i]) return false;
    }
    return false;
  }

  /// Public constructor, useful for constructing a fake [VersionStatus] in tests.
  VersionStatus({
    this.localVersion,
    this.storeVersion,
    this.appStoreLink,
    this.originalStoreVersion,
  });

  VersionStatus._({
    this.localVersion,
    this.storeVersion,
    this.appStoreLink,
    this.originalStoreVersion,
  });
}

class _LocalPackageInfo {
  final String packageName;
  final String version;
  const _LocalPackageInfo({required this.packageName, required this.version});
}

const MethodChannel _packageInfoChannel = MethodChannel('device_safety_info');

Future<_LocalPackageInfo> _fetchPackageInfo() async {
  final result = await _packageInfoChannel.invokeMapMethod<String, dynamic>(
    'getPackageInfo',
  );
  return _LocalPackageInfo(
    packageName: result?['packageName'] as String? ?? '',
    version: result?['version'] as String? ?? '0.0.0',
  );
}

/// Checks whether a newer version of this app is available on the iOS App Store or Android Play
/// Store, by querying each store's public lookup endpoint directly — no server of your own needed.
class NewVersionChecker {
  /// The app's bundle ID on the App Store. Falls back to the local package name if omitted.
  final String? iOSId;

  /// The app's package name on the Play Store. Falls back to the local package name if omitted.
  final String? androidId;

  /// The App Store country/storefront to query, e.g. `'us'`.
  final String? iOSAppStoreCountry;

  /// The Play Store locale to query, e.g. `'en_US'`.
  final String? androidPlayStoreCountry;

  /// Overrides the detected store version — useful for testing `canUpdate` logic without a real
  /// network call.
  final String? forceAppVersion;

  NewVersionChecker({
    this.androidId,
    this.iOSId,
    this.iOSAppStoreCountry,
    this.forceAppVersion,
    this.androidPlayStoreCountry,
  });

  /// Queries the appropriate app store for this platform and returns a [VersionStatus], or `null`
  /// if the platform isn't supported or the store couldn't be reached.
  Future<VersionStatus?> getVersionStatus() async {
    final packageInfo = await _fetchPackageInfo();
    if (Platform.isIOS) {
      return _getiOSStoreVersion(packageInfo);
    } else if (Platform.isAndroid) {
      return _getAndroidStoreVersion(packageInfo);
    } else {
      debugPrint(
        'The target platform "${Platform.operatingSystem}" is not yet supported by this package.',
      );
      return null;
    }
  }

  /// Returns the cleaned local app version (e.g. `1.2.3`), read from the native package info.
  Future<String> getLocalVersion() async {
    final localPackageInfo = await _fetchPackageInfo();
    return RegExp(r'\d+\.\d+(\.\d+)?').stringMatch(localPackageInfo.version) ??
        '0.0.0';
  }

  String _getCleanVersion(String version) =>
      RegExp(r'\d+\.\d+(\.\d+)?').stringMatch(version) ?? '0.0.0';

  Future<VersionStatus?> _getiOSStoreVersion(
    _LocalPackageInfo packageInfo,
  ) async {
    final id = iOSId ?? packageInfo.packageName;
    final parameters = {"bundleId": id};
    if (iOSAppStoreCountry != null) {
      parameters.addAll({"country": iOSAppStoreCountry ?? ''});
    }
    var uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    final response = await simpleHttpGet(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query iOS App Store');
      return null;
    }
    final jsonObj = json.decode(response.body);
    final List<dynamic> results = jsonObj['results'] as List<dynamic>;
    if (results.isEmpty) {
      debugPrint('Can\'t find an app in the App Store with the id: $id');
      return null;
    }
    final firstResult = results[0] as Map<String, dynamic>;
    return VersionStatus._(
      localVersion: _getCleanVersion(packageInfo.version),
      storeVersion: _getCleanVersion(
        forceAppVersion ?? firstResult['version'] as String,
      ),
      originalStoreVersion:
          forceAppVersion ?? firstResult['version'] as String?,
      appStoreLink: firstResult['trackViewUrl'] as String?,
    );
  }

  Future<VersionStatus?> _getAndroidStoreVersion(
    _LocalPackageInfo packageInfo,
  ) async {
    final id = androidId ?? packageInfo.packageName;
    final uri = Uri.https("play.google.com", "/store/apps/details", {
      "id": id.toString(),
      "hl": androidPlayStoreCountry ?? "en_US",
    });
    final response = await simpleHttpGet(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query Android Play Store: ${response.statusCode}');
      return null;
    }

    final regexp = RegExp(
      r'\[\[\[\"(\d+\.\d+(\.[a-z]+)?(\.([^"]|\\")*)?)\"\]\]',
    );
    final storeVersion = regexp.firstMatch(response.body)?.group(1);

    return VersionStatus._(
      localVersion: _getCleanVersion(packageInfo.version),
      storeVersion: _getCleanVersion(forceAppVersion ?? storeVersion ?? ""),
      originalStoreVersion: forceAppVersion ?? storeVersion ?? "",
      appStoreLink: uri.toString(),
    );
  }
}
