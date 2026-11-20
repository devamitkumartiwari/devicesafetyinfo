import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

/// The frame every feature page uses: what the feature does, the code to copy, and the demo.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.about,
    required this.code,
    required this.children,
    this.platforms = 'Android and iOS',
  });

  /// Page title, e.g. "Root / jailbreak".
  final String title;

  /// One or two plain sentences: what it does and why it matters.
  final String about;

  /// The snippet to copy into your app (same as the README).
  final String code;

  /// Where the feature works, e.g. "Android only".
  final String platforms;

  /// The live demo.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(about, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Works on: $platforms',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          CodeBox(code),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A grey box with monospace code.
class CodeBox extends StatelessWidget {
  const CodeBox(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

/// Shows the outcome of the last button press, and runs actions so that a
/// [DeviceSafetyException] (e.g. "not supported on this platform") is shown instead of thrown.
mixin StatusMessage<T extends StatefulWidget> on State<T> {
  String? status;

  /// Runs [action] and shows the text it returns, or the error.
  Future<void> run(Future<String> Function() action) async {
    String text;
    try {
      text = await action();
    } on DeviceSafetyException catch (e) {
      text = 'Error: $e';
    } on Exception catch (e) {
      text = 'Error: $e';
    }
    if (mounted) setState(() => status = text);
  }

  /// The message, or nothing before the first action. Errors are shown in red.
  Widget statusText() {
    final text = status;
    if (text == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final isError = text.startsWith('Error');
    return Card(
      color: isError ? colors.errorContainer : colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? colors.error : colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                key: const ValueKey('status_message'),
                style: TextStyle(
                  color: isError
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
