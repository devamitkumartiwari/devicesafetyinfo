import 'dart:typed_data';

import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/device_key_info.dart';
import '../domain/device_key.dart';

/// Hardware-bound keys through the platform API.
final class DeviceKeyRepositoryImpl implements DeviceKeyRepository {
  /// Creates the repository.
  DeviceKeyRepositoryImpl(this._platform);

  final DeviceKeyHostApi _platform;

  @override
  Future<DeviceKeyInfo> create(
    String alias, {
    Uint8List? challenge,
    required bool preferStrongBox,
  }) async =>
      (await _platform.create(alias, challenge, preferStrongBox)).toDomain();

  @override
  Future<DeviceKeyInfo?> info(String alias) async =>
      (await _platform.info(alias))?.toDomain();

  @override
  Future<Uint8List> sign(String alias, Uint8List data) =>
      _platform.sign(alias, data);

  @override
  Future<bool> exists(String alias) => _platform.exists(alias);

  @override
  Future<void> delete(String alias) => _platform.delete(alias);
}
