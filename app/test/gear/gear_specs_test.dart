import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_specs.dart';

void main() {
  test('table sizes', () {
    expect(pedalSpecs.length, 86);
    expect(ampSpecs.length, 38);
    expect(cabSpecs.length, 28);
  });

  test('known entries', () {
    expect(pedalSpecs['Scream']!.family, PedalFamily.ts);
    expect(ampSpecs['Brit 800']!.isHead, true);
    expect(cabSpecs['BritGN 4x12']!.slant, true);
    expect(cabSpecs['BritGN 4x12']!.speakers, 4);
    expect(cabSpecs.containsKey('User IR 1'), true);
  });

  test('every pedal has knob names', () {
    for (final e in pedalSpecs.entries) {
      expect(e.value.knobNames, isNotEmpty, reason: e.key);
    }
    for (final e in ampSpecs.entries) {
      expect(e.value.knobNames, isNotEmpty, reason: e.key);
    }
  });
}
