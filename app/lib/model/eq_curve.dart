/// An approximate magnitude response for the CFW Global EQ models, for the
/// curve drawn in the app. Frequencies and Q come from the data's own knob
/// mappings; the filter shapes are textbook analog prototypes (Butterworth
/// cuts, RBJ shelves and bells), not the pedal's exact DSP — good for showing
/// what a knob does, not for measuring.
library;

import 'dart:math' as math;

import 'cfw_eq_models.dart';

/// The model's gain in dB at [freq] Hz for the block's 8 [slots]. Always
/// finite: out-of-range slot values are clamped.
double eqCurveDb(CfwEqModel model, List<int> slots, double freq) {
  CfwEqParam? byName(String name) {
    for (final p in model.params) {
      if (p.name == name) return p;
    }

    return null;
  }

  num raw(CfwEqParam p) {
    final slot = p.algId >= 0 && p.algId < slots.length ? slots[p.algId] : 0;

    return p.fromSlot(slot).clamp(p.min, p.max);
  }

  double gain(String name) {
    final p = byName(name);

    return p == null ? 0 : raw(p).toDouble();
  }

  double hz(String name, double fallback) {
    final p = byName(name);

    return p == null ? fallback : p.mapped(raw(p)).clamp(10.0, 30000.0);
  }

  // A cut knob's corner, or null when the knob is at its "off" value.
  double? corner(String name) {
    final p = byName(name);

    if (p == null || raw(p) == p.mapOff) return null;

    return p.mapped(raw(p)).clamp(10.0, 30000.0);
  }

  final q = switch (byName('Q')) {
    final p? => p.mapped(raw(p)).clamp(0.1, 20.0),
    null => 0.7071,
  };
  final f = freq.clamp(1.0, 96000.0);
  var db = 0.0;

  switch (model.key) {
    case 'studio':
      db += _lowShelf(f, 100, gain('Bass'));
      db += _bell(f, hz('Mid Freq', 800), gain('Mid'), q);
      db += _highShelf(f, 4000, gain('Treble'));
    case 'para3':
      db += _bell(f, hz('Low F', 100), gain('Low'), q);
      db += _bell(f, hz('Mid F', 800), gain('Mid'), q);
      db += _bell(f, hz('High F', 3000), gain('High'), q);
    case 'tilt':
      final pivot = hz('Pivot', 800);
      final tilt = gain('Tilt');

      db += _lowShelf(f, pivot, -tilt / 2) + _highShelf(f, pivot, tilt / 2);
  }

  // Cut 24 switches its cuts between 12 and 24 dB/oct; the others are 12.
  final order = model.key == 'cut24' && gain('24dB') != 0 ? 4 : 2;

  if (corner('Low Cut') case final fc?) db += _cut(fc / f, order);
  if (corner('High Cut') case final fc?) db += _cut(f / fc, order);

  return db.isFinite ? db : 0;
}

/// Butterworth cut of [order]: x is (corner / f) for a low cut, (f / corner)
/// for a high cut. -3 dB at x = 1.
double _cut(double x, int order) =>
    -10 * math.log(1 + math.pow(x, 2 * order)) / math.ln10;

double _db(double magSquared) => 10 * math.log(magSquared) / math.ln10;

/// RBJ analog bell: [gainDb] at [f0], width set by [q].
double _bell(double f, double f0, double gainDb, double q) {
  if (gainDb == 0) return 0;

  final a = math.pow(10, gainDb / 40).toDouble();
  final w = f / f0;
  final d = (1 - w * w) * (1 - w * w);

  return _db((d + math.pow(a * w / q, 2)) / (d + math.pow(w / (a * q), 2)));
}

const _shelfQ = 0.7071;

/// RBJ analog low shelf: [gainDb] below [f0].
double _lowShelf(double f, double f0, double gainDb) {
  if (gainDb == 0) return 0;

  final a = math.pow(10, gainDb / 40).toDouble();
  final w = f / f0;
  final mid = a * w * w / (_shelfQ * _shelfQ);

  return _db(
    a * a * (math.pow(a - w * w, 2) + mid) / (math.pow(1 - a * w * w, 2) + mid),
  );
}

/// RBJ analog high shelf: [gainDb] above [f0].
double _highShelf(double f, double f0, double gainDb) {
  if (gainDb == 0) return 0;

  final a = math.pow(10, gainDb / 40).toDouble();
  final w = f / f0;
  final mid = a * w * w / (_shelfQ * _shelfQ);

  return _db(
    a * a * (math.pow(1 - a * w * w, 2) + mid) / (math.pow(a - w * w, 2) + mid),
  );
}
