import 'dart:convert';
import 'dart:io';

class SimpleHttpResponse {
  final int statusCode;
  final String body;
  const SimpleHttpResponse(this.statusCode, this.body);
}

const Duration _defaultTimeout = Duration(seconds: 10);

Future<SimpleHttpResponse> simpleHttpGet(Uri uri) async {
  final client = HttpClient()..connectionTimeout = _defaultTimeout;
  try {
    final request = await client.getUrl(uri).timeout(_defaultTimeout);
    final response = await request.close().timeout(_defaultTimeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_defaultTimeout);
    return SimpleHttpResponse(response.statusCode, body);
  } finally {
    client.close();
  }
}
