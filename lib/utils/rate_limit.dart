import 'package:http/http.dart' as http;

final _retryPattern = RegExp(r'try again in (\d+(?:\.\d+)?)s', caseSensitive: false);
const _maxRetries = 8;

Duration _delay(String body, Map<String, String> headers) {
  final header = headers['retry-after'];
  if (header != null) {
    final s = double.tryParse(header);
    if (s != null) return Duration(milliseconds: (s * 1000).ceil() + 200);
  }
  final m = _retryPattern.firstMatch(body);
  if (m != null) {
    final s = double.parse(m.group(1)!);
    return Duration(milliseconds: (s * 1000).ceil() + 500);
  }
  return const Duration(seconds: 10);
}

/// Non-streaming POST with silent 429 retry.
Future<http.Response> postWithRetry(
  Uri uri, {
  required Map<String, String> headers,
  required String body,
}) async {
  for (int i = 0; i < _maxRetries; i++) {
    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 429) return resp;
    await Future.delayed(_delay(resp.body, resp.headers));
  }
  return http.post(uri, headers: headers, body: body);
}

/// Streaming send with silent 429 retry.
/// [build] is called fresh on each attempt since a Request can only be sent once.
Future<http.StreamedResponse> sendWithRetry(
  http.Client client,
  http.Request Function() build,
) async {
  for (int i = 0; i < _maxRetries; i++) {
    final resp = await client.send(build());
    if (resp.statusCode != 429) return resp;
    final body = await resp.stream.bytesToString();
    await Future.delayed(_delay(body, resp.headers));
  }
  return client.send(build());
}
