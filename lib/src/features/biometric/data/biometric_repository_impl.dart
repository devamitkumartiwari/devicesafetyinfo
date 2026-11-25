import 'dart:typed_data';

import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/device_key_info.dart';
import '../domain/biometric_repository.dart';

/// Biometric-bound keys through the platform API.
final class BiometricRepositoryImpl implements BiometricRepository {
  /// Creates the repository.
  BiometricRepositoryImpl(this._platform);

  final BiometricHostApi _platform;

  @override
  Future<bool> isAvailable() => _platform.isAvailable();

  @override
  Future<DeviceKeyInfo> enroll(String alias) async =>
      (await _platform.enroll(alias)).toDomain();

  @override
  Future<Uint8List> approve(
    String alias,
    Uint8List payload, {
    required String title,
    required String reason,
  }) => _platform.approve(alias, payload, title, reason);

  @override
  Future<BiometricKeyState> keyState(String alias) async =>
      switch (await _platform.keyState(alias)) {
        BiometricKeyStateMsg.valid => BiometricKeyState.valid,
        BiometricKeyStateMsg.invalidated => BiometricKeyState.invalidated,
        BiometricKeyStateMsg.missing => BiometricKeyState.missing,
      };

  @override
  Future<void> delete(String alias) => _platform.delete(alias);
}
