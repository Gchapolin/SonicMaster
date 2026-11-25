import 'dart:convert';
import 'dart:io';

/// GETs [url] and returns the body as UTF-8 text. Throws [HttpException] on a
/// non-200 status; network errors and [timeout] throw as they come.
Future<String> httpGetText(
  Uri url, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;

  try {
    final res = await (await client.getUrl(url)).close().timeout(timeout);
    final body = await res.transform(utf8.decoder).join().timeout(timeout);

    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }

    return body;
  } finally {
    client.close(force: true);
  }
}
