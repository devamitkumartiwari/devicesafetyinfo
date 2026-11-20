import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Live threat events: screenshots, screen recording, VPN, tapjacking, new detections.
///
/// ```dart
/// DeviceSafety.threats.listen((event) {
///   print('${event.type.name}: ${event.detail}');
/// });
/// ```
class ThreatsPage extends StatefulWidget {
  const ThreatsPage({super.key});

  @override
  State<ThreatsPage> createState() => _ThreatsPageState();
}

class _ThreatsPageState extends State<ThreatsPage> {
  final _events = <ThreatEvent>[];
  bool? _captured;
  late final List<StreamSubscription<Object?>> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      DeviceSafety.threats.listen(
        (event) => setState(() => _events.insert(0, event)),
      ),
      DeviceSafety.screen.captureChanges.listen(
        (captured) => setState(() => _captured = captured),
        onError: (Object _) {},
      ),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Live threats',
      about:
          'One stream for everything that happens while the app runs: a screenshot, '
          'screen recording starting, a VPN connecting, a covered tap, or a check that '
          'becomes detected.',
      code: '''DeviceSafety.threats.listen((event) {
  print('\${event.type.name}: \${event.detail}');
});''',
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cast),
            title: const Text('Screen captured'),
            trailing: Text(
              _captured == null ? '-' : (_captured! ? 'yes' : 'no'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Take a screenshot to see an event.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_events.isEmpty) const ListTile(title: Text('No events yet')),
        for (final e in _events.take(30))
          ListTile(
            leading: Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(e.detail ?? '${e.type.name} detected'),
            subtitle: Text('${e.type.name} · ${e.at.toLocal()}'),
          ),
      ],
    );
  }
}
