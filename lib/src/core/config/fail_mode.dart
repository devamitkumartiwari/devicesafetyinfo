/// What a check reports when it fails or times out instead of completing.
enum FailMode {
  /// Treat the failure as "not detected". The default: a broken check never blocks a user.
  open,

  /// Treat the failure as "detected". For security-critical apps where an attacker might
  /// deliberately make a check fail.
  closed,
}
