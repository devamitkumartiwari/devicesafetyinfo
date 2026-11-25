import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/app_switcher_repository.dart';

/// App switcher privacy through the platform API.
final class AppSwitcherRepositoryImpl implements AppSwitcherRepository {
  /// Creates the repository.
  AppSwitcherRepositoryImpl(this._platform);

  final AppSwitcherHostApi _platform;

  @override
  Future<void> setRecentsOverlay(int argb) => _platform.setRecentsOverlay(argb);

  @override
  Future<void> clearRecentsOverlay() => _platform.clearRecentsOverlay();

  @override
  Future<void> hideFromRecents(bool hide) => _platform.hideFromRecents(hide);
}
