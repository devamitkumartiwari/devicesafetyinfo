/// Which indicators make a check report `detected`.
enum RiskPolicy {
  /// The check doesn't run. Its result has status `CheckStatus.skipped` and is never detected.
  off,

  /// Only clear evidence (`RiskLevel.high`) counts. The recommended default: it doesn't flag
  /// normal devices that merely have unusual stock firmware.
  standard,

  /// Any indicator (`RiskLevel.low` or `RiskLevel.high`) counts. Expect some normal devices,
  /// often budget phones and custom ROMs, to be flagged.
  strict,
}
