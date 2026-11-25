import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// GETs [url] with the browser's fetch and returns the body as text. Throws
/// on a non-200 status, a network error or [timeout].
Future<String> httpGetText(
  Uri url, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final res = await web.window
      .fetch(url.toString().toJS)
      .toDart
      .timeout(timeout);

  if (res.status != 200) throw Exception('HTTP ${res.status}: $url');

  return (await res.text().toDart.timeout(timeout)).toDart;
}
