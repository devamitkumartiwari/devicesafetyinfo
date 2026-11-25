import 'dart:async';

import 'package:device_safety_info/src/core/utils/ttl_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late Duration ttl;
  late TtlCache<String, int> cache;
  var loads = 0;

  Future<int> load() async => ++loads;

  setUp(() {
    now = DateTime(2026);
    ttl = const Duration(seconds: 10);
    loads = 0;
    cache = TtlCache(ttl: () => ttl, clock: () => now);
  });

  test('caches until the ttl expires', () async {
    expect(await cache.get('k', load), 1);
    now = now.add(const Duration(seconds: 9));
    expect(await cache.get('k', load), 1);
    now = now.add(const Duration(seconds: 1));
    expect(await cache.get('k', load), 2);
  });

  test('concurrent callers share one in-flight load', () async {
    final gate = Completer<int>();
    var calls = 0;
    Future<int> slow() {
      calls++;
      return gate.future;
    }

    final a = cache.get('k', slow);
    final b = cache.get('k', slow);
    expect(identical(a, b), isTrue);
    gate.complete(42);
    expect(await Future.wait([a, b]), [42, 42]);
    expect(calls, 1);
  });

  test('different keys load independently', () async {
    expect(await cache.get('a', load), 1);
    expect(await cache.get('b', load), 2);
  });

  test('errors reach every caller and are not cached', () async {
    final gate = Completer<int>();
    final a = cache.get('k', () => gate.future);
    final b = cache.get('k', () => gate.future);
    gate.completeError(StateError('boom'));
    await expectLater(a, throwsStateError);
    await expectLater(b, throwsStateError);
    expect(await cache.get('k', load), 1);
  });

  test('synchronous throw from load becomes a failed future', () async {
    await expectLater(
      cache.get('k', () => throw StateError('sync')),
      throwsStateError,
    );
    expect(await cache.get('k', load), 1);
  });

  test('shouldCache false is returned but not stored', () async {
    expect(await cache.get('k', load, shouldCache: (_) => false), 1);
    expect(await cache.get('k', load), 2);
  });

  test('zero ttl stores nothing but still dedupes', () async {
    ttl = Duration.zero;
    expect(await cache.get('k', load), 1);
    expect(await cache.get('k', load), 2);
    expect(cache.peek('k'), isNull);
  });

  test('ttl is read at store time', () async {
    await cache.get('k', load);
    ttl = const Duration(seconds: 1);
    cache.put('k', 5);
    now = now.add(const Duration(seconds: 1));
    expect(cache.peek('k'), isNull);
  });

  test('invalidate drops the entry', () async {
    await cache.get('k', load);
    cache.invalidate('k');
    expect(await cache.get('k', load), 2);
  });

  test('a load started before invalidate is not stored', () async {
    final gate = Completer<int>();
    final old = cache.get('k', () => gate.future);
    cache.invalidate('k');
    final fresh = cache.get('k', load);
    gate.complete(99);
    expect(await old, 99);
    expect(await fresh, 1);
    expect(cache.peek('k')?.value, 1);
  });

  test('clear drops everything, including in-flight stores', () async {
    await cache.get('a', load);
    final gate = Completer<int>();
    final pending = cache.get('b', () => gate.future);
    cache.clear();
    gate.complete(7);
    expect(await pending, 7);
    expect(cache.peek('a'), isNull);
    expect(cache.peek('b'), isNull);
  });
}
