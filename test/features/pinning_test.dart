import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/features/pinning/domain/spki.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

// Self-signed P-256 certificate for localhost / 127.0.0.1 and its throwaway key, in
// test/fixtures/pinning. The key is left out of the published package (.pubignore).
//
// The certificate must be valid for at most 825 days and carry the serverAuth EKU: macOS
// rejects longer-lived TLS server certificates even from a trusted custom root, so a longer
// validity makes the TLS tests below fail on Mac only. It expires 2029-02-22. Renew it from the
// same key (keeps every pin in this file unchanged) with:
//   cd test/fixtures/pinning && openssl req -x509 -key localhost.key -out localhost.crt \
//     -days 820 -subj "/CN=localhost" \
//     -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
//     -addext "extendedKeyUsage=serverAuth" -addext "basicConstraints=critical,CA:TRUE"
const _fixtures = 'test/fixtures/pinning';
final _certPem = File('$_fixtures/localhost.crt').readAsStringSync();
final _keyFile = File('$_fixtures/localhost.key');

// From: openssl x509 -pubkey -noout | openssl pkey -pubin -outform der
//   | openssl dgst -sha256 -binary | base64
const _pin = 'fk9XHhHbogE9XGaAfesn/HnyYWU7bGalXhRCxlOPYMI=';
final _otherPin = base64.encode(List.filled(32, 7));
final _backupPin = base64.encode(List.filled(32, 9));

Uint8List _der(String pem) => base64.decode(
  const LineSplitter()
      .convert(pem)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join(),
);

void main() {
  group('spki', () {
    test('matches openssl for a real certificate', () {
      final spki = spkiOf(_der(_certPem));
      expect(spki.first, 0x30);
      expect(spki.length, 91, reason: 'P-256 SubjectPublicKeyInfo');
      expect(spkiSha256(_der(_certPem)), _pin);
    });

    test('rejects malformed input', () {
      expect(() => spkiOf(Uint8List(0)), throwsFormatException);
      expect(
        () => spkiOf(Uint8List.fromList([0x31, 0])),
        throwsFormatException,
      );
      final truncated = _der(_certPem).sublist(0, 60);
      expect(() => spkiOf(truncated), throwsFormatException);
      expect(
        () => spkiOf(Uint8List.fromList([0x30, 0x85, 1, 1, 1, 1, 1])),
        throwsFormatException,
      );
    });
  });

  group('PinningConfig', () {
    test('needs two valid pins per host', () {
      expect(
        () => PinningConfig({
          'a.com': {_pin},
        }),
        throwsArgumentError,
      );
      expect(
        () => PinningConfig({
          'a.com': {_pin, 'not-base64!'},
        }),
        throwsArgumentError,
      );
      expect(
        () => PinningConfig({
          'a.com': {
            _pin,
            base64.encode([1, 2, 3]),
          },
        }),
        throwsArgumentError,
      );
    });

    test('host lookup, case and subdomains', () {
      final exact = PinningConfig({
        'Example.com': {_pin, _backupPin},
      });
      expect(exact.pinsFor('EXAMPLE.com'), {_pin, _backupPin});
      expect(exact.pinsFor('api.example.com'), isNull);
      expect(exact.pinsFor('other.com'), isNull);
      final sub = PinningConfig({
        'example.com': {_pin, _backupPin},
      }, includeSubdomains: true);
      expect(sub.pinsFor('a.b.example.com'), isNotNull);
      expect(sub.pinsFor('example.org'), isNull);
      expect(sub.pinsFor('notexample.com'), isNull);
    });
  });

  group(
    'pinned HttpClient against a local TLS server',
    skip: _keyFile.existsSync() ? false : 'test key not present',
    () {
      late HttpServer server;
      late SecurityContext trust;
      late Fakes f;
      late DeviceSafetyClient client;
      var served = 0;

      setUp(() async {
        served = 0;
        final serverCtx = SecurityContext()
          ..useCertificateChainBytes(utf8.encode(_certPem))
          ..usePrivateKeyBytes(_keyFile.readAsBytesSync());
        server = await HttpServer.bindSecure('127.0.0.1', 0, serverCtx);
        server.listen((r) {
          served++;
          r.response
            ..write('ok')
            ..close();
        });
        trust = SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificatesBytes(utf8.encode(_certPem));
        f = Fakes();
        client = DeviceSafety.forTesting(platform: f.platform());
      });

      tearDown(() async {
        await server.close(force: true);
        await client.dispose();
        DeviceSafety.resetForTesting();
      });

      Future<String> get(HttpClient http, [String host = 'localhost']) async {
        try {
          final req = await http.getUrl(
            Uri.parse('https://$host:${server.port}/'),
          );
          final res = await req.close();
          return await res.transform(utf8.decoder).join();
        } finally {
          http.close(force: true);
        }
      }

      test('the right pin connects', () async {
        final http = DeviceSafety.pinning.createHttpClient(
          PinningConfig({
            'localhost': {_otherPin, _pin},
          }),
          context: trust,
        );
        expect(await get(http), 'ok');
      });

      test('a wrong pin fails before the request and emits a threat', () async {
        final events = <ThreatEvent>[];
        final sub = DeviceSafety.threats.listen(events.add);
        final http = DeviceSafety.pinning.createHttpClient(
          PinningConfig({
            'localhost': {_otherPin, _backupPin},
          }),
          context: trust,
        );
        await expectLater(
          get(http),
          throwsA(
            isA<PinningException>()
                .having((e) => e.host, 'host', 'localhost')
                .having((e) => e.toString(), 'toString', contains('localhost')),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(served, 0, reason: 'no request reached the server');
        expect(events.single.type, CheckType.mitm);
        expect(events.single.detail, 'pin_mismatch:localhost');
        await sub.cancel();
      });

      test('unpinned hosts use normal TLS validation', () async {
        final pinned = PinningConfig({
          'api.example.com': {_otherPin, _backupPin},
        });
        expect(
          await get(
            DeviceSafety.pinning.createHttpClient(pinned, context: trust),
          ),
          'ok',
        );
        // Without the test CA trusted, the self-signed server is rejected as usual.
        await expectLater(
          get(DeviceSafety.pinning.createHttpClient(pinned)),
          throwsA(isA<HandshakeException>()),
        );
      });

      test('plain HTTP to a pinned host is refused', () async {
        final http = DeviceSafety.pinning.createHttpClient(
          PinningConfig({
            'localhost': {_otherPin, _pin},
          }),
        );
        try {
          await expectLater(
            http.getUrl(Uri.parse('http://localhost:${server.port}/')),
            throwsA(isA<PinningException>()),
          );
        } finally {
          http.close(force: true);
        }
      });

      test('spkiPinOf reads the server pin', () async {
        expect(
          await DeviceSafety.pinning.spkiPinOf(
            Uri.parse('https://localhost:${server.port}'),
            context: trust,
          ),
          _pin,
        );
      });
    },
  );
}
