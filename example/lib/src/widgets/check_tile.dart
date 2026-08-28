import 'package:material_ui/material_ui.dart';

/// Displays a tri-state (unknown / yes / no) result for a single security check.
class CheckTile extends StatelessWidget {
  const CheckTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
  });

  final String title;
  final bool? value;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final unknown = value == null;
    final positive = value == true;
    final color = unknown
        ? Colors.orange
        : (positive ? Colors.green : Colors.red);
    final bgColor = unknown
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (positive ? Colors.green.shade50 : Colors.red.shade50);
    final displayIcon = unknown
        ? Icons.help_outline
        : (positive ? (icon ?? Icons.check_circle) : (icon ?? Icons.cancel));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: bgColor,
          child: Icon(displayIcon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: unknown
            ? const Text('—')
            : Chip(
                side: BorderSide.none,
                label: Text(positive ? 'Yes' : 'No'),
                backgroundColor: positive
                    ? Colors.green.shade100
                    : Colors.red.shade100,
              ),
      ),
    );
  }
}
