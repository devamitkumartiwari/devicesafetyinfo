import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_scaffold.dart';
import 'result_view.dart';

/// A page for one detection check: runs it when opened and when you tap "Run again".
class CheckPage extends StatefulWidget {
  const CheckPage({
    super.key,
    required this.title,
    required this.about,
    required this.code,
    required this.check,
    this.platforms = 'Android and iOS',
  });

  final String title;
  final String about;
  final String code;
  final String platforms;

  /// The check to run, e.g. `DeviceSafety.root.check`.
  final Future<CheckResult> Function({bool refresh}) check;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  CheckResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _result = null);
    final result = await widget.check(refresh: true);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: widget.title,
      about: widget.about,
      code: widget.code,
      platforms: widget.platforms,
      children: [
        ResultView(_result),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('run_check'),
          onPressed: _run,
          icon: const Icon(Icons.refresh),
          label: const Text('Run again'),
        ),
      ],
    );
  }
}
