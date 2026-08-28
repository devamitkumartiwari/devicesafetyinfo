import 'package:material_ui/material_ui.dart';

/// Shows a blocking "Are you sure?" dialog with [message]; calls [onConfirm] only if the user
/// taps Confirm (Cancel just dismisses).
Future<void> confirmDialog(
  BuildContext context,
  String message,
  VoidCallback onConfirm,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Are you sure?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}
