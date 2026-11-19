/// Matches hosts against an indicator-of-compromise (IOC) domain blocklist. Pure Dart.
///
/// Entries are exact hosts (`evil.example`) or wildcard suffixes (`*.evil.example`, which
/// matches subdomains but not `evil.example` itself). Matching is case-insensitive.
final class IocDomainMatcher {
  final Set<String> _exact = {};
  final Set<String> _suffixes = {};

  /// Number of entries.
  int get length => _exact.length + _suffixes.length;

  /// Replaces the blocklist with [domains]. Blank entries are ignored.
  void replace(Iterable<String> domains) {
    _exact.clear();
    _suffixes.clear();
    for (final raw in domains) {
      final d = raw.trim().toLowerCase();
      if (d.isEmpty) continue;
      if (d.startsWith('*.')) {
        _suffixes.add(d.substring(2));
      } else {
        _exact.add(d);
      }
    }
  }

  /// Whether [host] is on the blocklist.
  bool isBlocked(String host) {
    final h = host.trim().toLowerCase();
    if (_exact.contains(h)) return true;
    for (final s in _suffixes) {
      if (h.endsWith('.$s')) return true;
    }
    return false;
  }

  /// Parses a feed with one domain per line; blank lines and `#` comments are skipped.
  static List<String> parseFeed(String body) => [
    for (final line in body.split('\n'))
      if (line.trim() case final t when t.isNotEmpty && !t.startsWith('#')) t,
  ];
}
