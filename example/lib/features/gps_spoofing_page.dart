import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// GPS spoofing.
///
/// ```dart
/// final result = await DeviceSafety.locationSpoofing.check();
/// if (result.detected) rejectLocation();
/// ```
class GpsSpoofingPage extends StatelessWidget {
  const GpsSpoofingPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'GPS spoofing',
    about: 'Finds a fake-location app chosen in developer options, or a fake location fix.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.locationSpoofing.check();
if (result.detected) rejectLocation();
print(result.signals); // what was found''',
    check: DeviceSafety.locationSpoofing.check,
  );
}
