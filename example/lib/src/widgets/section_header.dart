import 'package:material_ui/material_ui.dart';

/// A bold section title used to separate groups of demo tiles in the ListView.
Widget sectionHeader(BuildContext context, String label) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
  child: Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.bold),
  ),
);
