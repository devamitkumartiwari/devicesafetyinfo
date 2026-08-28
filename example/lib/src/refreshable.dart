/// Implemented by a section's `State` when it exposes a manual refresh action, so
/// [HomePage] can wire a single, uniformly-typed refresh button into that section's
/// [FeaturePage] without a separate helper per section.
abstract interface class Refreshable {
  Future<void> refresh();
}
