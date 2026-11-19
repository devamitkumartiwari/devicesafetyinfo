/// How urgently the app should be updated.
enum UpdateUrgency {
  /// The installed version is current.
  none,

  /// A newer version is available.
  optional,

  /// The installed version is below the minimum supported version.
  required,
}

/// Compares dotted version strings numerically (`1.10.0` > `1.9.3`). Non-digits in a segment
/// are ignored and missing segments count as 0. Returns <0, 0 or >0.
int compareVersions(String a, String b) {
  final sa = a.split('.');
  final sb = b.split('.');
  final n = sa.length > sb.length ? sa.length : sb.length;
  for (var i = 0; i < n; i++) {
    int seg(List<String> s) => i < s.length
        ? int.tryParse(s[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
        : 0;
    final va = seg(sa);
    final vb = seg(sb);
    if (va != vb) return va < vb ? -1 : 1;
  }
  return 0;
}

/// Extracts `major.minor[.patch]` from a version string, or `0.0.0`.
String cleanVersion(String version) =>
    RegExp(r'\d+\.\d+(\.\d+)?').stringMatch(version) ?? '0.0.0';

/// The installed app.
final class AppInfo {
  /// Creates the entity.
  const AppInfo({
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  /// Android package name or iOS bundle id.
  final String packageName;

  /// Version name, e.g. `2.3.1`.
  final String version;

  /// Version code (Android) or build number (iOS).
  final String buildNumber;
}

/// The installed version compared with the store version.
final class VersionStatus {
  /// Creates the status.
  const VersionStatus({
    required this.localVersion,
    required this.storeVersion,
    this.originalStoreVersion,
    this.storeLink,
    this.minAppVersion,
  });

  /// Installed version (cleaned to `major.minor[.patch]`).
  final String localVersion;

  /// Store version (cleaned).
  final String storeVersion;

  /// Store version as the store reported it.
  final String? originalStoreVersion;

  /// Link to the store listing.
  final String? storeLink;

  /// Minimum supported version, if one was given.
  final String? minAppVersion;

  /// Whether the store has a newer version.
  bool get canUpdate => compareVersions(localVersion, storeVersion) < 0;

  /// How urgent the update is.
  UpdateUrgency get urgency {
    final min = minAppVersion;
    if (min != null && compareVersions(localVersion, min) < 0) {
      return UpdateUrgency.required;
    }
    return canUpdate ? UpdateUrgency.optional : UpdateUrgency.none;
  }
}

/// The installed app's info and the store's published version.
abstract interface class VersionRepository {
  Future<AppInfo> appInfo();

  /// The App Store version for [bundleId] (falling back to the numeric [appStoreId]), with the
  /// store link; `null` if not found.
  Future<({String version, String? link})?> appStoreVersion(
    String bundleId, {
    String? country,
    String? appStoreId,
  });

  /// The Play Store version for [packageName], with the store link; `null` if not found.
  Future<({String version, String link})?> playStoreVersion(
    String packageName, {
    String? locale,
  });
}
