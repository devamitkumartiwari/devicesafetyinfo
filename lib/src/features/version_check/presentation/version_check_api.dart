import '../../../core/platform/action_guard.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/version_status.dart';

export '../domain/version_status.dart'
    show AppInfo, UpdateUrgency, VersionStatus, compareVersions;

/// App info and store update checks.
final class VersionCheckApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.versionCheck`.
  VersionCheckApi(this._repository);

  final VersionRepository _repository;

  /// The installed app's package name, version and build number.
  Future<AppInfo> appInfo() => guardAction('appInfo', _repository.appInfo);

  /// The installed version, cleaned to `major.minor[.patch]`.
  Future<String> localVersion() async =>
      cleanVersion((await appInfo()).version);

  /// Compares the installed version with the store's. Returns `null` when the store can't be
  /// reached or parsed, so `null` never proves that no update exists.
  ///
  /// [iOSId] / [androidId] default to the installed package name. [minAppVersion] makes
  /// [VersionStatus.urgency] report [UpdateUrgency.required] below that version.
  /// [forceAppVersion] overrides the store version (for testing your update UI).
  Future<VersionStatus?> status({
    String? iOSId,
    String? iOSAppStoreId,
    String? iOSAppStoreCountry,
    String? androidId,
    String? androidPlayStoreLocale,
    String? minAppVersion,
    String? forceAppVersion,
  }) async {
    final info = await appInfo();
    final ({String version, String? link})? store;
    if (PlatformGuard.isIOS) {
      store = await _repository.appStoreVersion(
        iOSId ?? info.packageName,
        country: iOSAppStoreCountry,
        appStoreId: iOSAppStoreId,
      );
    } else if (PlatformGuard.isAndroid) {
      store = await _repository.playStoreVersion(
        androidId ?? info.packageName,
        locale: androidPlayStoreLocale,
      );
    } else {
      return null;
    }
    final storeVersion = forceAppVersion ?? store?.version;
    if (storeVersion == null) return null;
    return VersionStatus(
      localVersion: cleanVersion(info.version),
      storeVersion: cleanVersion(storeVersion),
      originalStoreVersion: storeVersion,
      storeLink: store?.link,
      minAppVersion: minAppVersion,
    );
  }
}
