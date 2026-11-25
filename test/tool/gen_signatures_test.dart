import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_signatures.dart';

void main() {
  test('encode/decode round-trips and hides the plain text', () {
    const values = ['/system/xbin/su', '/data/adb/ksu', 'ünïcode'];
    final bytes = encode('suPaths', values);
    expect(decode('suPaths', bytes), values);
    expect(String.fromCharCodes(bytes), isNot(contains('/system')));
  });

  test('generated files are up to date with tool/signatures.json', () {
    final files = generateAll(
      File(jsonPath).readAsStringSync(),
      File(manifestPath).readAsStringSync(),
    );
    for (final MapEntry(key: path, value: content) in files.entries) {
      expect(
        File(path).readAsStringSync().replaceAll('\r\n', '\n'),
        content,
        reason: '$path is stale; run `dart run tool/gen_signatures.dart`',
      );
    }
  });

  test('every queried package is in the manifest', () {
    final lists = readLists(File(jsonPath).readAsStringSync());
    final manifest = File(manifestPath).readAsStringSync();
    for (final list in queriedLists) {
      for (final p in lists[list]!) {
        expect(manifest, contains('android:name="$p"'));
      }
    }
  });
}
