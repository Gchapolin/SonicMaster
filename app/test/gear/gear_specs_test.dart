import 'package:flutter/painting.dart';
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

  test('amp panels keep the prototype ink and the two-tone bass panel', () {
    final twin = ampSpecs['Dark Twin']!.panel;
    expect(twin.top, const Color(0xFF1A1A1A));
    expect(twin.ink, const Color(0xFFEDEDED));
    expect(ampSpecs['Flyman B1']!.panel.ink, const Color(0xFFD7B76A));
    expect(ampSpecs['Brit 800']!.panel.worn, true);
    expect(ampSpecs['Eng 120']!.panel.worn, false);
    final svt = ampSpecs['A BassVT']!.panel;
    expect(svt.top, const Color(0xFFC9CDD2));
    expect(svt.band, const Color(0xFF2C4F8C));
    expect(ampSpecs['Brit 800']!.panel.band, isNull);
  });
}
