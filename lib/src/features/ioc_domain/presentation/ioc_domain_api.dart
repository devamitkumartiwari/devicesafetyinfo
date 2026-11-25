import '../../../core/result/device_safety_exception.dart';
import '../../../core/utils/http_get.dart';
import '../domain/ioc_domain_matcher.dart';

/// Blocks requests to known-malicious domains. Check hosts before connecting:
///
/// ```dart
/// if (DeviceSafety.ioc.isBlocked(uri.host)) return;
/// ```
final class IocDomainApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.ioc`. [httpGet] is injectable for
  /// tests.
  IocDomainApi({
    IocDomainMatcher? matcher,
    Future<SimpleHttpResponse> Function(Uri uri)? httpGet,
  }) : _matcher = matcher ?? IocDomainMatcher(),
       _get = httpGet ?? simpleHttpGet;

  final IocDomainMatcher _matcher;
  final Future<SimpleHttpResponse> Function(Uri uri) _get;

  /// Whether [host] is blocked.
  bool isBlocked(String host) => _matcher.isBlocked(host);

  /// Number of blocklist entries.
  int get length => _matcher.length;

  /// Replaces the blocklist.
  void updateBlocklist(Iterable<String> domains) => _matcher.replace(domains);

  /// Downloads a feed (one domain per line, `#` comments) and replaces the blocklist with it.
  /// Throws [NativeFailureException] if the download fails; the current list is kept.
  Future<void> loadRemoteBlocklist(Uri feedUrl) async {
    final response = await _get(feedUrl);
    if (response.statusCode != 200) {
      throw NativeFailureException(
        'HTTP_${response.statusCode}',
        'Failed to load IOC blocklist from $feedUrl',
      );
    }
    _matcher.replace(IocDomainMatcher.parseFeed(response.body));
  }
}
