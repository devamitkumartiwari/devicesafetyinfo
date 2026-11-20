import 'dart:typed_data';

import '../../../core/result/device_key_info.dart';

/// Hardware-bound signing keys.
abstract interface class DeviceKeyRepository {
  Future<DeviceKeyInfo> create(
    String alias, {
    Uint8List? challenge,
    required bool preferStrongBox,
  });
  Future<DeviceKeyInfo?> info(String alias);
  Future<Uint8List> sign(String alias, Uint8List data);
  Future<bool> exists(String alias);
  Future<void> delete(String alias);
}
