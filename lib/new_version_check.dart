import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

class VersionStatus {
  final String? localVersion;

  final String? storeVersion;

  final String? originalStoreVersion;

  final String? appStoreLink;

  bool get canUpdate {
    final local = localVersion?.split('.').map(int.parse).toList();
    final store = storeVersion?.split('.').map(int.parse).toList();

    for (var i = 0; i < store!.length; i++) {
      // store version field is newer than the local version.
      if (store[i] > local![i]) {
        return true;
      }

      // local version field is newer than the store version.
      if (local[i] > store[i]) {
        return false;
      }
    }

    // local and store versions are the same.
    return false;
  }

  //public constructor
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

class NewVersionChecker {
  final String? iOSId;

  final String? androidId;

  final String? iOSAppStoreCountry;

  final String? androidPlayStoreCountry;

  final String? forceAppVersion;

  NewVersionChecker({
    this.androidId,
    this.iOSId,
    this.iOSAppStoreCountry,
    this.forceAppVersion,
    this.androidPlayStoreCountry,
  });

  Future<VersionStatus?> getVersionStatus() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (Platform.isIOS) {
      return _getiOSStoreVersion(packageInfo);
    } else if (Platform.isAndroid) {
      return _getAndroidStoreVersion(packageInfo);
    } else {
      debugPrint('The target platform "${Platform.operatingSystem}" is not yet supported by this package.');
      return null;
    }
  }

  Future<String> getLocalVersion() async {
    PackageInfo localPackageInfo = await PackageInfo.fromPlatform();
    return RegExp(r'\d+\.\d+(\.\d+)?').stringMatch(localPackageInfo.version) ?? '0.0.0';
  }

  String _getCleanVersion(String version) => RegExp(r'\d+\.\d+(\.\d+)?').stringMatch(version) ?? '0.0.0';

  Future<VersionStatus?> _getiOSStoreVersion(PackageInfo packageInfo) async {
    final id = iOSId ?? packageInfo.packageName;
    final parameters = {"bundleId": id};
    if (iOSAppStoreCountry != null) {
      parameters.addAll({"country": iOSAppStoreCountry ?? ''});
    }
    var uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query iOS App Store');
      return null;
    }
    final jsonObj = json.decode(response.body);
    final List results = jsonObj['results'];
    if (results.isEmpty) {
      debugPrint('Can\'t find an app in the App Store with the id: $id');
      return null;
    }
    return VersionStatus._(
      localVersion: _getCleanVersion(packageInfo.version),
      storeVersion: _getCleanVersion(forceAppVersion ?? jsonObj['results'][0]['version']),
      originalStoreVersion: forceAppVersion ?? jsonObj['results'][0]['version'],
      appStoreLink: jsonObj['results'][0]['trackViewUrl'],
    );
  }

  Future<VersionStatus> _getAndroidStoreVersion(PackageInfo packageInfo) async {
    final id = androidId ?? packageInfo.packageName;
    final uri = Uri.https("play.google.com", "/store/apps/details", {"id": id.toString(), "hl": androidPlayStoreCountry ?? "en_US"});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception("Invalid response code: ${response.statusCode}");
    }

    final regexp = RegExp(r'\[\[\[\"(\d+\.\d+(\.[a-z]+)?(\.([^"]|\\")*)?)\"\]\]');
    final storeVersion = regexp.firstMatch(response.body)?.group(1);

    return VersionStatus._(
      localVersion: _getCleanVersion(packageInfo.version),
      storeVersion: _getCleanVersion(forceAppVersion ?? storeVersion ?? ""),
      originalStoreVersion: forceAppVersion ?? storeVersion ?? "",
      appStoreLink: uri.toString(),
    );
  }
}

enum LaunchModeVersion { normal, external }
