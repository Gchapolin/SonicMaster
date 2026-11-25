// Fetches a text resource over HTTP(S): dart:io's HttpClient on native,
// the browser's fetch on web. The conditional export picks the side.
export 'http_get_io.dart' if (dart.library.js_interop) 'http_get_web.dart';
