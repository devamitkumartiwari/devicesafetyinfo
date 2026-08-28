import 'package:material_ui/material_ui.dart';

/// A focused, single-feature destination page: an [AppBar] with [title] and an
/// optional refresh action, wrapping [child] in a scrollable, safe-area body.
class FeaturePage extends StatelessWidget {
  const FeaturePage({
    super.key,
    required this.title,
    required this.child,
    this.onRefresh,
  });

  /// Shown in the [AppBar] and used as the back-navigation label.
  final String title;

  /// The feature section rendered below the app bar.
  final Widget child;

  /// When non-null, shows a refresh action (app bar icon + pull-to-refresh).
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: onRefresh == null
            ? null
            : [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
              ],
      ),
      body: SafeArea(
        child: onRefresh == null
            ? body
            : RefreshIndicator(onRefresh: onRefresh!, child: body),
      ),
    );
  }
}
