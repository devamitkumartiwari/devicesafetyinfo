import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';

/// IOC (indicator-of-compromise) domain-blocklist demo.
class IocDomainSection extends StatefulWidget {
  const IocDomainSection({super.key});

  @override
  State<IocDomainSection> createState() => IocDomainSectionState();
}

class IocDomainSectionState extends State<IocDomainSection> {
  final TextEditingController _iocController = TextEditingController(
    text: 'sub.evil.com',
  );
  String? _iocResult;

  @override
  void initState() {
    super.initState();
    IOCDomainBlocker.updateBlocklist(['evil.com', '*.evil.com']);
  }

  @override
  void dispose() {
    _iocController.dispose();
    super.dispose();
  }

  void _checkIocDomain() {
    final host = _iocController.text.trim();
    final blocked = IOCDomainBlocker.isBlocked(host);
    setState(() => _iocResult = blocked ? 'Blocked' : 'Not blocked');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'IOC Domain Check'),
        DemoCard(
          children: [
            Text(
              'Seeded with: evil.com, *.evil.com',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _iocController,
              decoration: const InputDecoration(
                labelText: 'Hostname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _checkIocDomain,
                  icon: const Icon(Icons.search),
                  label: const Text('Check Domain'),
                ),
                if (_iocResult != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _iocResult!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _iocResult == 'Blocked'
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
