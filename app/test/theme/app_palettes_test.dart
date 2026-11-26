import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_palettes.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;

  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('appPalettes has the 18 Adobe palettes in order', () {
    expect(appPalettes.length, 18);
    expect(appPalettes.first.id, 'vintage');
    expect(appPalettes.first.bg, const Color(0xFF3E2C28));
    expect(appPalettes.first.acc, const Color(0xFFDF9D8E));
    expect(appPalettes.last.name, 'Mayflower');
  });

  test('every palette keeps text readable', () {
    for (final p in appPalettes) {
      expect(contrast(p.text, p.sel), greaterThanOrEqualTo(4.5), reason: p.id);
      expect(
        contrast(p.muted, p.ctrl),
        greaterThanOrEqualTo(4.5),
        reason: p.id,
      );
      expect(contrast(p.acc, p.card), greaterThanOrEqualTo(4.5), reason: p.id);
      expect(contrast(p.onAcc, p.acc), greaterThanOrEqualTo(4.5), reason: p.id);
      expect(contrast(p.text, p.bg), greaterThanOrEqualTo(7), reason: p.id);
    }
  });

  test('paletteById falls back to vintage', () {
    expect(paletteById('nope').id, 'vintage');
    expect(paletteById(null).id, 'vintage');
  });
}
