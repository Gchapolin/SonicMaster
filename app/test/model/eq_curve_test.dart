import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_eq_models.dart';
import 'package:sonicmaster/model/eq_curve.dart';

void main() {
  final models = parseCfwEqModels(
    jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  CfwEqModel named(String n) => models.firstWhere((m) => m.name == n);
  List<int> slots(CfwEqModel m, Map<String, num> values) {
    final s = m.defaultSlots();

    for (final e in values.entries) {
      final p = m.params.firstWhere((p) => p.name == e.key);

      s[p.algId] = p.toSlot(e.value);
    }

    return s;
  }

  test('knob values map to the frequencies the data shows', () {
    final studio = named('Studio EQ');
    final lowCut = studio.params.firstWhere((p) => p.name == 'Low Cut');
    final mid = studio.params.firstWhere((p) => p.name == 'Mid Freq');

    expect(lowCut.mapped(7), closeTo(26, 0.5)); // text: 26Hz
    expect(lowCut.mapped(100), closeTo(800, 5)); // text: 800Hz
    expect(mid.mapped(-50), closeTo(100, 1)); // text: 100Hz
    expect(mid.mapped(50), closeTo(6400, 40)); // text: 6.40kHz
  });

  test('every model is flat at its defaults, except where it cuts', () {
    for (final name in ['Studio EQ', 'Parametric 3', 'Tilt EQ']) {
      final m = named(name);

      for (final f in [50.0, 1000.0, 8000.0]) {
        expect(
          eqCurveDb(m, m.defaultSlots(), f),
          closeTo(0, 0.01),
          reason: '$name $f',
        );
      }
    }
  });

  test('Studio EQ: bass shelf, treble shelf and the mid bell', () {
    final m = named('Studio EQ');
    final bass = slots(m, {'Bass': 6});

    expect(eqCurveDb(m, bass, 25), closeTo(6, 0.6));
    expect(eqCurveDb(m, bass, 5000), closeTo(0, 0.2));

    final treble = slots(m, {'Treble': -6});

    expect(eqCurveDb(m, treble, 16000), closeTo(-6, 0.7));
    expect(eqCurveDb(m, treble, 100), closeTo(0, 0.2));

    final mid = slots(m, {'Mid': 9});

    expect(eqCurveDb(m, mid, 800), closeTo(9, 0.01)); // Mid Freq 0 = 800 Hz
    expect(eqCurveDb(m, mid, 80), lessThan(1));
  });

  test('cuts: -3 dB at the corner, off means flat', () {
    final m = named('Studio EQ');
    final cut = slots(m, {'Low Cut': 50});
    final fc = m.params.firstWhere((p) => p.name == 'Low Cut').mapped(50);

    expect(eqCurveDb(m, cut, fc), closeTo(-3.01, 0.05));
    expect(eqCurveDb(m, cut, fc / 4), lessThan(-20));
    expect(eqCurveDb(m, m.defaultSlots(), 21), closeTo(0, 0.01)); // Off
  });

  test('Cut 24 is steeper with 24dB on', () {
    final m = named('Cut 24');
    final on = slots(m, {'24dB': 1});
    final off = slots(m, {'24dB': 0});
    final fc = m.params.firstWhere((p) => p.name == 'Low Cut').mapped(38);

    expect(eqCurveDb(m, on, fc / 2), lessThan(eqCurveDb(m, off, fc / 2) - 8));
  });

  test('Parametric 3 bells sit on their own frequencies', () {
    final m = named('Parametric 3');
    final low = slots(m, {'Low': 6, 'High': -6});
    final lowF = m.params.firstWhere((p) => p.name == 'Low F').mapped(33);
    final highF = m.params.firstWhere((p) => p.name == 'High F').mapped(40);

    expect(eqCurveDb(m, low, lowF), closeTo(6, 0.3));
    expect(eqCurveDb(m, low, highF), closeTo(-6, 0.3));
  });

  test('Tilt: positive brightens, negative darkens, around the pivot', () {
    final m = named('Tilt EQ');
    final bright = slots(m, {'Tilt': 6});

    expect(eqCurveDb(m, bright, 12000), greaterThan(2));
    expect(eqCurveDb(m, bright, 60), lessThan(-2));
    expect(eqCurveDb(m, bright, 800), closeTo(0, 0.3)); // Pivot 0 = 800 Hz
  });

  test('never returns a non-finite value', () {
    for (final m in models) {
      for (final f in [1.0, 20.0, 20000.0, 96000.0]) {
        expect(eqCurveDb(m, List.filled(8, 127), f).isFinite, isTrue);
        expect(eqCurveDb(m, List.filled(8, -128), f).isFinite, isTrue);
      }
    }
  });
}
