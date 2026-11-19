/// Hides app content in the app switcher (recents) screen.
abstract interface class AppSwitcherRepository {
  Future<void> setRecentsOverlay(int argb);
  Future<void> clearRecentsOverlay();
  Future<void> hideFromRecents(bool hide);
}
