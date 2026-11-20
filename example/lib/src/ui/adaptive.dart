// The example's only style-aware code. Every page is written once against these widgets, which
// render as Material or Cupertino depending on AppState.uiStyle.
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';

export 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
export 'package:material_ui/material_ui.dart' show Icons;

/// Whether the app is currently rendered in Cupertino style.
bool get isCupertino => AppState.instance.uiStyle.value == UiStyle.cupertino;

/// [material] in Material style, [cupertino] in Cupertino style.
IconData adaptiveIcon(IconData material, IconData cupertino) =>
    isCupertino ? cupertino : material;

/// Semantic colors shared by both styles.
abstract final class StatusColors {
  static const danger = Color(0xFFD32F2F);
  static const warning = Color(0xFFEF6C00);
  static const caution = Color(0xFFB27C00);
  static const ok = Color(0xFF2E7D32);
  static const muted = Color(0xFF757575);
}

/// Pushes [page] with the platform-appropriate transition.
Future<void> pushPage(BuildContext context, Widget page) => Navigator.push(
  context,
  isCupertino
      ? CupertinoPageRoute<void>(builder: (_) => page)
      : MaterialPageRoute<void>(builder: (_) => page),
);

/// A page with a navigation bar, an optional refresh action and a scrolling body.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onRefresh,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      final trailing = [
        ...actions,
        if (onRefresh != null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRefresh,
            child: const Icon(CupertinoIcons.refresh),
          ),
      ];
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: trailing.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              if (onRefresh != null)
                CupertinoSliverRefreshControl(onRefresh: onRefresh),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ],
          ),
        ),
      );
    }
    final body = SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
        ],
      ),
      body: SafeArea(
        child: onRefresh == null
            ? body
            : RefreshIndicator(onRefresh: onRefresh!, child: body),
      ),
    );
  }
}

/// A titled group of rows.
class AdaptiveSection extends StatelessWidget {
  const AdaptiveSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (isCupertino) {
      return CupertinoListSection.insetGrouped(
        header: header == null ? null : Text(header!.toUpperCase()),
        footer: footer == null ? null : Text(footer!),
        children: children,
      );
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                header!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(footer!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Arbitrary content padded to sit inside an [AdaptiveSection].
class SectionContent extends StatelessWidget {
  const SectionContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Align(alignment: AlignmentDirectional.centerStart, child: child),
  );
}

/// A row with optional leading, subtitle and trailing widgets.
class AdaptiveTile extends StatelessWidget {
  const AdaptiveTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2),
        trailing: trailing,
        onTap: onTap,
      );
    }
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// A bare on/off switch.
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => isCupertino
      ? CupertinoSwitch(value: value, onChanged: onChanged)
      : Switch(value: value, onChanged: onChanged);
}

/// A row with a switch; tapping anywhere on the row toggles it.
class AdaptiveSwitchTile extends StatelessWidget {
  const AdaptiveSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoListTile(
        leading: icon == null ? null : Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2),
        trailing: CupertinoSwitch(value: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
      );
    }
    return SwitchListTile(
      secondary: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A single-choice segmented control. Labels never wrap: Material drops the selected-check
/// icon and scales labels down to fit; Cupertino uses the sliding control.
class AdaptiveSegmented<T extends Object> extends StatelessWidget {
  const AdaptiveSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Value to label, in display order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: selected,
          children: {
            for (final MapEntry(:key, :value) in segments.entries)
              key: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(value, maxLines: 1),
              ),
          },
          onValueChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: [
          for (final MapEntry(:key, :value) in segments.entries)
            ButtonSegment(
              value: key,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, maxLines: 1, softWrap: false),
              ),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.single),
      ),
    );
  }
}

/// A primary ([filled]) or secondary button.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    if (isCupertino) {
      final child = icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                // iOS button text is large; let a long label wrap instead of overflowing.
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            );
      return filled
          ? CupertinoButton.filled(onPressed: onPressed, child: child)
          : CupertinoButton.tinted(onPressed: onPressed, child: child);
    }
    if (icon == null) {
      return filled
          ? FilledButton(onPressed: onPressed, child: text)
          : OutlinedButton(onPressed: onPressed, child: text);
    }
    return filled
        ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: text)
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: text,
          );
  }
}

/// A labelled single-line text field.
class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoTextField(
        controller: controller,
        placeholder: label,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            '$label:',
            style: const TextStyle(color: CupertinoColors.systemGrey),
          ),
        ),
      );
    }
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}

/// A small colored status label.
class AdaptiveChip extends StatelessWidget {
  const AdaptiveChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(isCupertino ? 6 : 8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
  );
}

/// A row that expands to show [children].
class AdaptiveExpandable extends StatefulWidget {
  const AdaptiveExpandable({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;

  @override
  State<AdaptiveExpandable> createState() => _AdaptiveExpandableState();
}

class _AdaptiveExpandableState extends State<AdaptiveExpandable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!isCupertino) {
      return ExpansionTile(
        leading: widget.leading,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
        trailing: widget.trailing,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: widget.children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoListTile(
          leading: widget.leading,
          title: Text(widget.title),
          subtitle: widget.subtitle == null
              ? null
              : Text(widget.subtitle!, maxLines: 2),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?widget.trailing,
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// A short, floating status message that never moves the page layout: a SnackBar in Material,
/// a toast at the bottom of the screen in Cupertino.
void showStatus(BuildContext context, String message) {
  if (!isCupertino) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, key: const ValueKey('status_message')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _toast?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: 48,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6202124),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message,
              key: const ValueKey('status_message'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer?.cancel();
  _toastTimer = Timer(const Duration(seconds: 3), () {
    if (identical(_toast, entry)) {
      entry.remove();
      _toast = null;
    }
  });
}

OverlayEntry? _toast;
Timer? _toastTimer;

/// Switches between Material and Cupertino.
class StyleToggleButton extends StatelessWidget {
  const StyleToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final label = isCupertino ? 'Switch to Material' : 'Switch to Cupertino';
    if (isCupertino) {
      return CupertinoButton(
        key: const ValueKey('style_toggle'),
        padding: EdgeInsets.zero,
        onPressed: AppState.instance.toggleStyle,
        child: Semantics(
          label: label,
          child: const Icon(CupertinoIcons.paintbrush),
        ),
      );
    }
    return IconButton(
      key: const ValueKey('style_toggle'),
      tooltip: label,
      icon: const Icon(Icons.phone_iphone),
      onPressed: AppState.instance.toggleStyle,
    );
  }
}
