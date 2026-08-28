import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../widgets/confirm_dialog.dart';
import '../widgets/section_header.dart';

/// Destructive Check-Hooked-&-Exit / Check-Hooked-&-Uninstall demo buttons.
class DangerZoneSection extends StatefulWidget {
  const DangerZoneSection({super.key});

  @override
  State<DangerZoneSection> createState() => DangerZoneSectionState();
}

class DangerZoneSectionState extends State<DangerZoneSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Danger Zone'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => confirmDialog(
                  context,
                  'This will exit the app if a hooking framework is detected.',
                  () => DeviceSafetyInfo.checkHooked(exitProcessIfTrue: true),
                ),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Check Hooked & Exit'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => confirmDialog(
                  context,
                  'This will attempt to uninstall the app if hooking is detected.',
                  () => DeviceSafetyInfo.checkHooked(uninstallIfTrue: true),
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Check Hooked & Uninstall'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
