import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/device_safety_channels.dart';
import '../http/simple_http_get.dart';

/// How urgently the user should be pushed to update, from [VersionStatus.urgency].
enum UpdateUrgency {
  /// No update available, or the store version couldn't be determined.
  none,

  /// A newer version is available, but the installed version still satisfies
  /// [VersionStatus.minAppVersion] (or none was supplied).
  optional,

  /// The installed version is below [VersionStatus.minAppVersion] — the developer-supplied
  /// threshold below which the app should refuse to proceed until updated.
  required,
}

/// Compares two dotted version strings segment-by-segment. Each segment is parsed permissively —
/// non-numeric characters are stripped and an unparseable/empty segment counts as `0` — so a
/// malformed version (e.g. a stray `"1.2.3-beta"` suffix, or an App/Play Store response with an
/// unexpected shape) degrades to a safe comparison instead of throwing. Returns -1/0/1 the way
/// [Comparable.compareTo] does.
int _compareVersions(String a, String b) {
  final segmentsA = a.split('.');
  final segmentsB = b.split('.');
  final length = segmentsA.length > segmentsB.length
      ? segmentsA.length
      : segmentsB.length;
  for (var i = 0; i < length; i++) {
    final segmentA = i < segmentsA.length ? segmentsA[i] : '0';
    final segmentB = i < segmentsB.length ? segmentsB[i] : '0';
    final valueA =
        int.tryParse(segmentA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final valueB =
        int.tryParse(segmentB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (valueA != valueB) return valueA < valueB ? -1 : 1;
  }
  return 0;
}

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

  /// The minimum acceptable version supplied to [NewVersionChecker.minAppVersion], echoed through
  /// for inspection. `null` if none was supplied.
  final String? minAppVersion;

  /// True if [storeVersion] is newer than [localVersion]. Malformed version strings compare
  /// safely (see [urgency] for a version-aware urgency level built on the same comparison).
  bool get canUpdate {
    if (localVersion == null || storeVersion == null) return false;
    return _compareVersions(localVersion!, storeVersion!) < 0;
  }

  /// How urgently the user should be pushed to update. Unlike [canUpdate], this also considers
  /// [minAppVersion] — a threshold supplied by the developer (from your own remote config or
  /// hardcoded), never scraped from the store, since anything parsed out of store HTML/metadata is
  /// one layout change away from breaking. Returns [UpdateUrgency.required] when [localVersion] is
  /// below [minAppVersion], [UpdateUrgency.optional] when [canUpdate] is true but not required, and
  /// [UpdateUrgency.none] otherwise.
  UpdateUrgency get urgency {
    if (localVersion != null &&
        minAppVersion != null &&
        _compareVersions(localVersion!, minAppVersion!) < 0) {
      return UpdateUrgency.required;
    }
    return canUpdate ? UpdateUrgency.optional : UpdateUrgency.none;
  }

  /// Public constructor, useful for constructing a fake [VersionStatus] in tests.
  VersionStatus({
    this.localVersion,
    this.storeVersion,
    this.appStoreLink,
    this.originalStoreVersion,
    this.minAppVersion,
  });

  VersionStatus._({
    this.localVersion,
    this.storeVersion,
    this.appStoreLink,
    this.originalStoreVersion,
    this.minAppVersion,
  });
}

class _LocalPackageInfo {
  final String packageName;
  final String version;
  const _LocalPackageInfo({required this.packageName, required this.version});
}

Future<_LocalPackageInfo> _fetchPackageInfo() async {
  final result = await DeviceSafetyChannels.method
      .invokeMapMethod<String, dynamic>('getPackageInfo');
  return _LocalPackageInfo(
    packageName: result?['packageName'] as String? ?? '',
    version: result?['version'] as String? ?? '0.0.0',
  );
}

/// Checks whether a newer version of this app is available on the iOS App Store or Android Play
/// Store, by querying each store's public lookup endpoint directly — no server of your own needed.
///
/// **Known limitation**: both the iOS and Android lookups are best-effort scraping/parsing of
/// endpoints neither store publishes as a stable, documented API — the iTunes lookup JSON shape
/// and the Play Store listing HTML have both changed unannounced in the past, elsewhere breaking
/// similar packages' version detection outright. This checker fails soft (returns `null` /
/// [UpdateUrgency.none] rather than throwing) when a response doesn't parse as expected, but a
/// `null` result should never be treated as proof no update exists.
class NewVersionChecker {
  /// The app's bundle ID on the App Store. Falls back to the local package name if omitted.
  final String? iOSId;

  /// The app's package name on the Play Store. Falls back to the local package name if omitted.
  final String? androidId;

  /// The App Store country/storefront to query, e.g. `'us'`.
  final String? iOSAppStoreCountry;

  /// The Play Store locale to query, e.g. `'en_US'`.
  final String? androidPlayStoreCountry;

  /// The app's numeric App Store ID (the "trackId"), used as a fallback lookup key if the
  /// [iOSId]-keyed (bundle ID) lookup returns no results — a real, reported failure mode when a
  /// bundle-ID lookup misses despite the app being live on the store. Ignored if not supplied.
  final String? iOSAppStoreId;

  /// Overrides the detected store version — useful for testing `canUpdate` logic without a real
  /// network call.
  final String? forceAppVersion;

  /// The minimum acceptable app version — see [VersionStatus.urgency]. Supply this from your own
  /// remote config or hardcode it; it is never read from the store.
  final String? minAppVersion;

  /// Creates a checker configured with the given store identifiers/overrides — see each field's
  /// own doc comment above.
  NewVersionChecker({
    this.androidId,
    this.iOSId,
    this.iOSAppStoreCountry,
    this.forceAppVersion,
    this.androidPlayStoreCountry,
    this.iOSAppStoreId,
    this.minAppVersion,
  });

  /// Queries the appropriate app store for this platform and returns a [VersionStatus], or `null`
  /// if the platform isn't supported or the store couldn't be reached/parsed.
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

  Future<Map<String, dynamic>?> _lookupITunes(
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    final response = await simpleHttpGet(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query iOS App Store');
      return null;
    }
    try {
      final jsonObj = json.decode(response.body) as Map<String, dynamic>;
      final results = jsonObj['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      return results[0] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to parse iOS App Store response: $e');
      return null;
    }
  }

  Future<VersionStatus?> _getiOSStoreVersion(
    _LocalPackageInfo packageInfo,
  ) async {
    final id = iOSId ?? packageInfo.packageName;
    final parameters = {"bundleId": id};
    if (iOSAppStoreCountry != null) {
      parameters.addAll({"country": iOSAppStoreCountry ?? ''});
    }

    var firstResult = await _lookupITunes(parameters);

    // A bundle-ID lookup can miss even for a live, published app (reported against similar
    // packages) — retry once against the numeric App Store ID if the caller supplied one.
    if (firstResult == null && iOSAppStoreId != null) {
      final fallbackParameters = {"id": iOSAppStoreId!};
      if (iOSAppStoreCountry != null) {
        fallbackParameters.addAll({"country": iOSAppStoreCountry ?? ''});
      }
      firstResult = await _lookupITunes(fallbackParameters);
    }

    if (firstResult == null) {
      debugPrint('Can\'t find an app in the App Store with the id: $id');
      return null;
    }

    try {
      final rawStoreVersion = firstResult['version'] as String?;
      if (rawStoreVersion == null) return null;
      return VersionStatus._(
        localVersion: _getCleanVersion(packageInfo.version),
        storeVersion: _getCleanVersion(forceAppVersion ?? rawStoreVersion),
        originalStoreVersion: forceAppVersion ?? rawStoreVersion,
        appStoreLink: firstResult['trackViewUrl'] as String?,
        minAppVersion: minAppVersion,
      );
    } catch (e) {
      debugPrint('Failed to read iOS App Store response fields: $e');
      return null;
    }
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

    try {
      final regexp = RegExp(
        r'\[\[\[\"(\d+\.\d+(\.[a-z]+)?(\.([^"]|\\")*)?)\"\]\]',
      );
      final storeVersion = regexp.firstMatch(response.body)?.group(1);

      return VersionStatus._(
        localVersion: _getCleanVersion(packageInfo.version),
        storeVersion: _getCleanVersion(forceAppVersion ?? storeVersion ?? ""),
        originalStoreVersion: forceAppVersion ?? storeVersion ?? "",
        appStoreLink: uri.toString(),
        minAppVersion: minAppVersion,
      );
    } catch (e) {
      debugPrint('Failed to parse Android Play Store response: $e');
      return null;
    }
  }
}
