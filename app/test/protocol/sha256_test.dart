import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/sha256.dart';

void main() {
  test('standard vectors', () {
    expect(
      sha256Hex([]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('inputs spanning several blocks', () {
    expect(
      sha256Hex(List.filled(1000, 0x61)),
      '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
    );
    expect(
      sha256Hex([for (var r = 0; r < 3; r++) ...List.generate(256, (i) => i)]),
      'f3a25aa93aa2fbba28d79260535bbd6a5eb0fc1c24a8b0f04e12b484c1dfe363',
    );
  });
}
