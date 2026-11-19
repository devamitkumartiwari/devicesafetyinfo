import 'package:flutter/services.dart';

import '../result/device_safety_exception.dart';

/// Runs a platform action, turning platform failures into typed [DeviceSafetyException]s.
/// Action APIs (blocking screenshots, copying to the clipboard, ...) use this; detection APIs
/// never throw.
Future<T> guardAction<T>(String operation, Future<T> Function() action) async {
  try {
    return await action();
  } on PlatformException catch (e) {
    throw switch (e.code) {
      'UNSUPPORTED' || 'UNSUPPORTED_PLATFORM' => UnsupportedPlatformException(
        operation,
        e.message,
      ),
      'PERMISSION_DENIED' ||
      'permission_denied' => PermissionMissingException(operation, e.message),
      _ => NativeFailureException.fromPlatform(e),
    };
  } on MissingPluginException catch (e) {
    throw UnsupportedPlatformException(operation, e.message);
  }
}
