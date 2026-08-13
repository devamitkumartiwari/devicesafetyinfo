import 'dart:convert';
import 'dart:io';

class SimpleHttpResponse {
  final int statusCode;
  final String body;
  const SimpleHttpResponse(this.statusCode, this.body);
}

Future<SimpleHttpResponse> simpleHttpGet(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return SimpleHttpResponse(response.statusCode, body);
  } finally {
    client.close();
  }
}
