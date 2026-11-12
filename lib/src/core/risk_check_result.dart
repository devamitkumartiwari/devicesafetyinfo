/// How strongly a check found signs of a risky environment (rooted / jailbroken device,
/// emulator / simulator, ...).
enum RiskLevel {
  /// No indicator was found.
  none,

  /// Only weak indicators were found — ones that also occur on normal, unmodified devices
  /// (e.g. a stock `busybox`, an unlocked bootloader, a `generic`/`unknown` build field).
  ///
  /// Recommended handling: allow the user in, log [RiskCheckResult.signals], and optionally add
  /// step-up verification for sensitive actions.
  low,

  /// Strong indicators were found — evidence that essentially never appears on a normal device
  /// (a working `su`, Magisk, emulator hardware such as `goldfish`/`ranchu`, ...).
  /// Recommended handling: block.
  high,
}

/// Which indicators count as a positive result for [DeviceSafetyInfo.isRooted],
/// [DeviceSafetyInfo.isEmulator] and [RiskCheckResult.isDetected].
enum RiskPolicy {
  /// Counts only clear evidence ([RiskLevel.high]). Allows devices that merely have unusual
  /// stock firmware. Recommended default.
  standard,

  /// Counts any indicator ([RiskLevel.low] or [RiskLevel.high]). Strictest; expect some normal
  /// devices (often budget Xiaomi/Redmi/Samsung/MediaTek phones) to be flagged.
  strict,
}

/// Detailed result of a tiered check such as [DeviceSafetyInfo.rootCheck] or
/// [DeviceSafetyInfo.emulatorCheck].
class RiskCheckResult {
  /// Builds a [RiskCheckResult] directly — useful for constructing a fake one in tests.
  const RiskCheckResult({
    required this.level,
    this.highRiskSignals = const [],
    this.lowRiskSignals = const [],
  });

  /// A result with no indicators.
  static const RiskCheckResult clean = RiskCheckResult(level: RiskLevel.none);

  /// Parses the map returned by a platform `rootCheck` / `emulatorCheck` method.
  factory RiskCheckResult.fromMap(Map<Object?, Object?> map) {
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toList(growable: false) : const [];

    final high = strings(map['highRiskSignals']);
    final low = strings(map['lowRiskSignals']);
    final level = switch (map['level']) {
      'high' => RiskLevel.high,
      'low' => RiskLevel.low,
      _ => RiskLevel.none,
    };
    return RiskCheckResult(
      // Never report a lower level than the signals justify.
      level: high.isNotEmpty
          ? RiskLevel.high
          : (low.isNotEmpty && level == RiskLevel.none ? RiskLevel.low : level),
      highRiskSignals: high,
      lowRiskSignals: low,
    );
  }

  /// The most severe level reached by any signal.
  final RiskLevel level;

  /// Strong indicators, e.g. `path:/system/bin/su`, `file:/data/adb/magisk`,
  /// `hardware:ranchu`, `prop:ro.kernel.qemu=1`, `ios:<reason>`.
  final List<String> highRiskSignals;

  /// Weak indicators, e.g. `path:/system/xbin/busybox`,
  /// `prop:ro.boot.verifiedbootstate=orange`, `manufacturer:unknown`.
  final List<String> lowRiskSignals;

  /// `true` when [level] is [RiskLevel.high] — i.e. [isDetected] under [RiskPolicy.standard].
  bool get isHighRisk => level == RiskLevel.high;

  /// Whether this result counts as a positive detection under [policy].
  ///
  /// * [RiskPolicy.standard] (default) — only [RiskLevel.high].
  /// * [RiskPolicy.strict] — [RiskLevel.low] counts too.
  bool isDetected({RiskPolicy policy = RiskPolicy.standard}) =>
      switch (policy) {
        RiskPolicy.standard => level == RiskLevel.high,
        RiskPolicy.strict => level != RiskLevel.none,
      };

  /// All signals, high-risk first. Suitable for logging / analytics.
  List<String> get signals => [...highRiskSignals, ...lowRiskSignals];

  /// Returns a copy with [signal] added at [risk] level, raising [level] if needed.
  RiskCheckResult withSignal(String signal, RiskLevel risk) {
    if (risk == RiskLevel.none || signals.contains(signal)) return this;
    final high = risk == RiskLevel.high
        ? [signal, ...highRiskSignals]
        : highRiskSignals;
    final low = risk == RiskLevel.low
        ? [signal, ...lowRiskSignals]
        : lowRiskSignals;
    return RiskCheckResult(
      level: risk.index > level.index ? risk : level,
      highRiskSignals: high,
      lowRiskSignals: low,
    );
  }

  @override
  String toString() =>
      'RiskCheckResult(level: ${level.name}, high: $highRiskSignals, low: $lowRiskSignals)';
}
