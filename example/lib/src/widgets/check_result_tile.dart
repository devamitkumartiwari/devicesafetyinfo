import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../ui/adaptive.dart';

/// Shows one [CheckResult]: detected or not, status, level, policy and every signal.
class CheckResultTile extends StatelessWidget {
  const CheckResultTile({super.key, required this.title, required this.result});

  final String title;
  final CheckResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (color, material, cupertino, label) = switch (r) {
      null => (
        StatusColors.muted,
        Icons.hourglass_empty,
        CupertinoIcons.hourglass,
        '...',
      ),
      CheckResult(status: CheckStatus.skipped) => (
        StatusColors.muted,
        Icons.block,
        CupertinoIcons.nosign,
        'off',
      ),
      CheckResult(status: CheckStatus.unsupported) => (
        StatusColors.muted,
        Icons.remove_circle_outline,
        CupertinoIcons.minus_circle,
        'n/a',
      ),
      CheckResult(detected: true) => (
        StatusColors.danger,
        Icons.warning_amber,
        CupertinoIcons.exclamationmark_triangle_fill,
        'DETECTED',
      ),
      CheckResult(status: CheckStatus.error || CheckStatus.timedOut) => (
        StatusColors.warning,
        Icons.error_outline,
        CupertinoIcons.exclamationmark_circle,
        r.status.name,
      ),
      CheckResult(level: RiskLevel.low) => (
        StatusColors.caution,
        Icons.info_outline,
        CupertinoIcons.info_circle,
        'low',
      ),
      _ => (
        StatusColors.ok,
        Icons.verified_user,
        CupertinoIcons.checkmark_shield_fill,
        'clean',
      ),
    };
    const detail = TextStyle(fontSize: 13);
    return AdaptiveExpandable(
      leading: Icon(adaptiveIcon(material, cupertino), color: color),
      title: title,
      subtitle: r == null
          ? null
          : '${r.status.name} · ${r.policy.name} · ${r.elapsed.inMilliseconds} ms',
      trailing: AdaptiveChip(label: label, color: color),
      children: [
        if (r != null && r.signals.isEmpty && r.error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('No signals', style: detail),
          ),
        if (r != null)
          for (final s in r.signals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: Icon(
                      adaptiveIcon(Icons.circle, CupertinoIcons.circle_fill),
                      size: 10,
                      color: s.level == RiskLevel.high
                          ? StatusColors.danger
                          : StatusColors.caution,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.id, style: detail),
                        Text(
                          '${s.level.name} · ${s.source.name}',
                          style: detail.copyWith(color: StatusColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (r?.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Error: ${r!.error}', style: detail),
          ),
      ],
    );
  }
}
