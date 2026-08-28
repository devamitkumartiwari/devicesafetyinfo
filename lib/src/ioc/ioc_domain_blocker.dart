import 'dart:async';

import 'package:flutter/foundation.dart';

import '../http/simple_http_get.dart';

/// Lightweight domain-reputation lookup for Indicators-of-Compromise (IOC) / command-and-control
/// (C2) domains. This is a client-side lookup utility only — wire [isBlocked] into your own HTTP
/// client interceptor or WebView navigation guard; this package does not intercept network
/// traffic itself and does not ship a maintained threat-intel feed. Supply your own list via
/// [updateBlocklist] or [loadRemoteBlocklist].
class IOCDomainBlocker {
  IOCDomainBlocker._();

  static final Set<String> _exactDomains = <String>{};
  static final Set<String> _wildcardSuffixes =
      <String>{}; // stored without the leading '*.'

  /// Returns true if [host] matches an entry in the current blocklist. Supports exact matches
  /// (`evil.com`) and wildcard subdomain entries (`*.evil.com`, which blocks `a.evil.com` and
  /// `a.b.evil.com` but not `evil.com` itself — same semantics as a TLS wildcard certificate;
  /// list the bare domain separately too if it should also be blocked).
  static bool isBlocked(String host) {
    final normalized = host.trim().toLowerCase();
    if (_exactDomains.contains(normalized)) return true;
    for (final suffix in _wildcardSuffixes) {
      if (normalized.endsWith('.$suffix')) return true;
    }
    return false;
  }

  /// Replaces the in-memory blocklist with [domains]. Entries starting with `*.` are treated as
  /// wildcard subdomain matches; all other entries are exact-match domains.
  static void updateBlocklist(List<String> domains) {
    _exactDomains.clear();
    _wildcardSuffixes.clear();
    for (final raw in domains) {
      final domain = raw.trim().toLowerCase();
      if (domain.isEmpty) continue;
      if (domain.startsWith('*.')) {
        _wildcardSuffixes.add(domain.substring(2));
      } else {
        _exactDomains.add(domain);
      }
    }
  }

  /// Fetches a newline-separated domain list from [feedUrl] and passes it to [updateBlocklist].
  /// Blank lines and lines starting with `#` are ignored (the comment convention used by common
  /// hosts-file-style threat-intel feeds).
  static Future<void> loadRemoteBlocklist(Uri feedUrl) async {
    final response = await simpleHttpGet(feedUrl);
    if (response.statusCode != 200) {
      debugPrint(
        'Failed to load IOC blocklist from $feedUrl: HTTP ${response.statusCode}',
      );
      return;
    }
    final domains = response.body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    updateBlocklist(domains);
  }
}
