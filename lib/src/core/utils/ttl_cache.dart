import 'dart:async';

/// A cache whose entries expire after a time-to-live, and which shares one in-flight load
/// among concurrent callers for the same key.
final class TtlCache<K, V> {
  /// Creates a cache. [ttl] is read on every store, so it can change at runtime. [clock] is
  /// injectable for tests.
  TtlCache({required this._ttl, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Duration Function() _ttl;
  final DateTime Function() _clock;
  final Map<K, ({V value, DateTime expiresAt})> _entries = {};
  final Map<K, Future<V>> _inFlight = {};

  // Bumped by invalidate/clear so a load that started earlier can't store a stale value.
  final Map<K, int> _keyGeneration = {};
  int _generation = 0;

  (int, int) _stamp(K key) => (_keyGeneration[key] ?? 0, _generation);

  /// The cached value for [key] if it hasn't expired; otherwise runs [load], shares it with
  /// any concurrent caller for the same key, and stores the value when [shouldCache] allows
  /// it (default: always). Errors from [load] reach every waiting caller and are never cached.
  Future<V> get(
    K key,
    Future<V> Function() load, {
    bool Function(V value)? shouldCache,
  }) {
    final hit = peek(key);
    if (hit != null) return Future.value(hit.value);
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final stamp = _stamp(key);
    late final Future<V> future;
    future = Future.sync(load)
        .then((value) {
          if (_stamp(key) == stamp && (shouldCache?.call(value) ?? true)) {
            put(key, value);
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], future)) _inFlight.remove(key);
        });
    _inFlight[key] = future;
    return future;
  }

  /// The unexpired entry for [key], or `null`.
  ({V value})? peek(K key) {
    final e = _entries[key];
    if (e == null) return null;
    if (!_clock().isBefore(e.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return (value: e.value);
  }

  /// Stores [value] for [key] for the current TTL. A zero or negative TTL stores nothing.
  void put(K key, V value) {
    final ttl = _ttl();
    if (ttl <= Duration.zero) return;
    _entries[key] = (value: value, expiresAt: _clock().add(ttl));
  }

  /// Drops the entry for [key]. A load already in progress still completes for its callers
  /// but isn't stored, and the next [get] starts a new load.
  void invalidate(K key) {
    _entries.remove(key);
    _inFlight.remove(key);
    _keyGeneration[key] = (_keyGeneration[key] ?? 0) + 1;
  }

  /// Drops every entry, with the same in-flight behavior as [invalidate].
  void clear() {
    _entries.clear();
    _inFlight.clear();
    _generation++;
  }
}
