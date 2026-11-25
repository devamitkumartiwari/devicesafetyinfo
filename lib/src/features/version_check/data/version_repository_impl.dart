import 'dart:convert';

import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/utils/http_get.dart';
import '../domain/version_status.dart';

/// App info from the platform; store versions from the public iTunes lookup API and the Play
/// Store listing page. Both store endpoints are undocumented and have changed before, so any
/// parsing failure yields `null` rather than an error.
final class VersionRepositoryImpl implements VersionRepository {
  /// Creates the repository. [httpGet] is injectable for tests.
  VersionRepositoryImpl(
    this._platform, {
    Future<SimpleHttpResponse> Function(Uri uri)? httpGet,
  }) : _get = httpGet ?? simpleHttpGet;

  final AppInfoHostApi _platform;
  final Future<SimpleHttpResponse> Function(Uri uri) _get;

  @override
  Future<AppInfo> appInfo() async {
    final m = await _platform.packageInfo();
    return AppInfo(
      packageName: m.packageName,
      version: m.version,
      buildNumber: m.buildNumber,
    );
  }

  @override
  Future<({String version, String? link})?> appStoreVersion(
    String bundleId, {
    String? country,
    String? appStoreId,
  }) async {
    Future<Map<String, Object?>?> lookup(Map<String, String> params) async {
      final response = await _get(
        Uri.https('itunes.apple.com', '/lookup', params),
      );
      if (response.statusCode != 200) return null;
      try {
        final results =
            (json.decode(response.body) as Map<String, Object?>)['results'];
        if (results is! List || results.isEmpty) return null;
        return results.first as Map<String, Object?>;
      } on Object {
        return null;
      }
    }

    final countryParam = {'country': ?country};
    // A bundle-id lookup can miss for a live app; retry with the numeric id if given.
    final result =
        await lookup({'bundleId': bundleId, ...countryParam}) ??
        (appStoreId == null
            ? null
            : await lookup({'id': appStoreId, ...countryParam}));
    final version = result?['version'];
    if (version is! String) return null;
    return (version: version, link: result?['trackViewUrl'] as String?);
  }

  @override
  Future<({String version, String link})?> playStoreVersion(
    String packageName, {
    String? locale,
  }) async {
    final uri = Uri.https('play.google.com', '/store/apps/details', {
      'id': packageName,
      'hl': locale ?? 'en_US',
    });
    final response = await _get(uri);
    if (response.statusCode != 200) return null;
    final match = RegExp(r'\[\[\["(\d+\.\d+(\.[a-z]+)?(\.([^"]|\\")*)?)"\]\]')
        .firstMatch(response.body);
    final version = match?.group(1);
    return version == null ? null : (version: version, link: uri.toString());
  }
}
