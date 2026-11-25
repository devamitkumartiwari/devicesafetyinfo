import '../../../core/platform/action_guard.dart';
import '../domain/app_switcher_repository.dart';

/// Keeps sensitive content out of the app switcher (recents) snapshot.
final class AppSwitcherApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.appSwitcher`.
  AppSwitcherApi(this._repository);

  final AppSwitcherRepository _repository;

  /// Covers the app with [argbColor] (e.g. `0xFF000000`) whenever it goes to the background.
  Future<void> setOverlay({int argbColor = 0xFF000000}) => guardAction(
    'setRecentsOverlay',
    () => _repository.setRecentsOverlay(argbColor),
  );

  /// Removes the overlay set by [setOverlay].
  Future<void> clearOverlay() =>
      guardAction('clearRecentsOverlay', _repository.clearRecentsOverlay);

  /// Excludes the app from the recents list (Android only; throws
  /// `UnsupportedPlatformException` on iOS).
  Future<void> hideFromRecents({bool hide = true}) =>
      guardAction('hideFromRecents', () => _repository.hideFromRecents(hide));
}
