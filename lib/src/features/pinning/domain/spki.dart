import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The DER-encoded SubjectPublicKeyInfo of an X.509 certificate ([certificateDer]).
///
/// Throws [FormatException] for anything that isn't a well-formed certificate.
Uint8List spkiOf(Uint8List certificateDer) {
  final b = certificateDer;
  final cert = _read(b, 0, b.length, 0x30);
  final tbs = _read(b, cert.contentStart, cert.end, 0x30);
  var p = tbs.contentStart;
  // Optional [0] version.
  if (_read(b, p, tbs.end) case final v when v.tag == 0xA0) p = v.end;
  // serialNumber, signature, issuer, validity, subject.
  for (var i = 0; i < 5; i++) {
    p = _read(b, p, tbs.end).end;
  }
  final spki = _read(b, p, tbs.end, 0x30);
  return Uint8List.sublistView(b, spki.start, spki.end);
}

/// The pin of a certificate: base64 of the SHA-256 of its SubjectPublicKeyInfo, the format
/// used by HPKP, OkHttp and Android's network security config. Get it for a server with
///
/// ```sh
/// openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null \
///   | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
///   | openssl dgst -sha256 -binary | base64
/// ```
String spkiSha256(Uint8List certificateDer) =>
    base64.encode(sha256.convert(spkiOf(certificateDer)).bytes);

final class _Tlv {
  const _Tlv(this.tag, this.start, this.contentStart, this.end);
  final int tag;
  final int start;
  final int contentStart;
  final int end;
}

_Tlv _read(Uint8List b, int pos, int limit, [int? expectTag]) {
  if (pos + 2 > limit) throw const FormatException('Truncated certificate');
  final tag = b[pos];
  if (expectTag != null && tag != expectTag) {
    throw FormatException('Unexpected DER tag 0x${tag.toRadixString(16)}');
  }
  var len = b[pos + 1];
  var p = pos + 2;
  if (len & 0x80 != 0) {
    final n = len & 0x7f;
    if (n == 0 || n > 4 || p + n > limit) {
      throw const FormatException('Bad DER length');
    }
    len = 0;
    for (var i = 0; i < n; i++) {
      len = (len << 8) | b[p++];
    }
  }
  final end = p + len;
  if (end > limit) throw const FormatException('Truncated certificate');
  return _Tlv(tag, pos, p, end);
}
