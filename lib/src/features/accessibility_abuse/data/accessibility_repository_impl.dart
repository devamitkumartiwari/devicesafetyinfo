import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/accessibility_signals.dart';

/// Reads enabled accessibility services from the platform.
final class AccessibilityRepositoryImpl implements AccessibilityRepository {
  /// Creates the repository.
  AccessibilityRepositoryImpl(this._platform);

  final PostureHostApi _platform;

  @override
  Future<List<AccessibilityService>> enabledServices() async => [
    for (final s in await _platform.enabledAccessibilityServices())
      s.toDomain(),
  ];
}

/// Converts the platform message.
extension AccessibilityServiceMsgMapping on AccessibilityServiceMsg {
  /// The domain entity.
  AccessibilityService toDomain() => AccessibilityService(
    id,
    canRetrieveWindowContent: canRetrieveWindowContent,
  );
}
