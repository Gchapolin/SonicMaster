import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/http_get.dart';

void main() {
  // flutter_test_config.dart initialises the test binding, which stubs every
  // HttpClient with a 400; this file talks to a real loopback server.
  setUpAll(() => HttpOverrides.global = null);

  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      final ok = req.uri.path == '/ok.json';

      req.response
        ..statusCode = ok ? 200 : 404
        ..write(ok ? '{"a": "ç"}' : 'nope')
        ..close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  test('returns the body as UTF-8 text', () async {
    expect(await httpGetText(url('/ok.json')), '{"a": "ç"}');
  });

  test('a non-200 status throws', () async {
    expect(httpGetText(url('/missing')), throwsA(isA<HttpException>()));
  });
}
