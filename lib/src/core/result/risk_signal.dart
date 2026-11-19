/// How strongly an indicator points to a risky environment.
enum RiskLevel {
  /// Not a risk. Only appears when a [RiskSignal] was overridden to `none`; such signals are
  /// dropped from results.
  none,

  /// A weak indicator that also occurs on normal devices (a stock `busybox`, an unlocked
  /// bootloader, a VPN). Counts as a detection only under `RiskPolicy.strict`.
  low,

  /// Clear evidence (a working `su`, Frida in memory, emulator hardware). Counts as a detection
  /// under `RiskPolicy.standard` and `RiskPolicy.strict`.
  high;

  /// The more severe of `this` and [other].
  RiskLevel max(RiskLevel other) => other.index > index ? other : this;
}

/// Where a [RiskSignal] was produced.
enum SignalSource {
  /// Kotlin or Swift platform code.
  platform,

  /// The native C checks, called through FFI.
  ffi,

  /// Dart code in this package.
  dart,
}

/// One indicator found by a check.
///
/// [id] is a stable, dotted identifier such as `root.su_executable` or `vpn.active`. Use it in
/// `DeviceSafetyConfig.signalOverrides` to change the level of a specific indicator. Ids are
/// static strings; the only variable part ever appended is an Android package name, for the
/// accessibility, notification-listener and malware checks (`malware.installed:com.example`).
final class RiskSignal {
  /// Creates a signal.
  const RiskSignal(this.id, this.level, {this.source = SignalSource.platform});

  /// Stable identifier, e.g. `root.su_executable`.
  final String id;

  /// Severity before or after overrides, depending on where this signal is read.
  final RiskLevel level;

  /// Where the signal was produced.
  final SignalSource source;

  /// The part of [id] before the first `:`, which is what `signalOverrides` keys match.
  /// For `malware.installed:com.example` this is `malware.installed`.
  String get key {
    final i = id.indexOf(':');
    return i < 0 ? id : id.substring(0, i);
  }

  /// A copy with a different [level].
  RiskSignal withLevel(RiskLevel level) =>
      level == this.level ? this : RiskSignal(id, level, source: source);

  @override
  bool operator ==(Object other) =>
      other is RiskSignal &&
      other.id == id &&
      other.level == level &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, level, source);

  @override
  String toString() => '$id(${level.name})';
}

/// The raw output of a check before policy is applied: what the platform and the native
/// checks found. Repositories produce these; the check runner turns them into `CheckResult`s.
final class CheckReport {
  /// Creates a report.
  const CheckReport(this.signals, {this.supported = true});

  /// A supported check that found nothing.
  static const CheckReport clean = CheckReport([]);

  /// A check that can't run on this platform or OS version.
  static const CheckReport unsupported = CheckReport([], supported: false);

  /// Everything that was found, at the level the producer assigned.
  final List<RiskSignal> signals;

  /// `false` when the check can't run here (wrong platform, OS too old).
  final bool supported;

  /// Combines two reports for the same check (e.g. platform and FFI results). The result is
  /// supported if either part is.
  CheckReport merge(CheckReport other) => CheckReport([
    ...signals,
    ...other.signals,
  ], supported: supported || other.supported);
}
