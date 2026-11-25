/// The CFW Global EQ models and their knobs, parsed from
/// assets/data/cfw_eq_models.json (data shipped by the Sonicake CFW app, MIT).
library;

import 'dart:math' as math;

/// One knob of a Global EQ model.
class CfwEqParam {
  const CfwEqParam({
    required this.name,
    required this.algId,
    required this.min,
    required this.max,
    required this.step,
    required this.defaultValue,
    required this.texts,
    this.kind = '',
    this.mapBase,
    this.mapK = 0,
    this.mapKNeg = 0,
    this.mapOff,
  });

  final String name;

  /// The knob's slot in the 8-byte block.
  final int algId;
  final num min;
  final num max;
  final num step;
  final num defaultValue;

  /// Display text per value ("26Hz", "+2.0dB"), keyed like the data file.
  final Map<String, String> texts;

  /// What the knob is ("db", "lcut", "hcut", "mid", "q", …).
  final String kind;

  /// The data's value mapping for frequency / Q knobs: the knob value v maps
  /// to `mapBase * 2^(k * v)` ([mapKNeg] for v < 0); [mapOff] is the value
  /// that switches the knob's filter off.
  final double? mapBase;
  final double mapK;
  final double mapKNeg;
  final num? mapOff;

  /// The mapped quantity (Hz, Q) for knob [value]; the value itself when the
  /// knob has no mapping.
  double mapped(num value) => mapBase == null
      ? value.toDouble()
      : mapBase! * math.pow(2, (value < 0 ? mapKNeg : mapK) * value);

  /// The raw slot value for [value]: knobs with a fractional step (dB, 0.5)
  /// travel in steps; the rest travel as they are.
  int toSlot(num value) => step < 1 ? (value / step).round() : value.round();

  num fromSlot(int slot) => step < 1 ? slot * step : slot;

  /// The data's text for [value], or the plain number.
  String textFor(num value) {
    final key = value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();

    return texts[key] ?? key;
  }
}

class CfwEqModel {
  const CfwEqModel({
    required this.wireIndex,
    required this.key,
    required this.name,
    required this.params,
  });

  /// The model byte of the Global EQ block.
  final int wireIndex;

  /// The data's model key: studio, para3, cut24, tilt.
  final String key;
  final String name;
  final List<CfwEqParam> params;

  /// The 8 slots with every knob at its default.
  List<int> defaultSlots() {
    final slots = List<int>.filled(8, 0);

    for (final p in params) {
      if (p.algId >= 0 && p.algId < 8) {
        slots[p.algId] = p.toSlot(p.defaultValue);
      }
    }

    return slots;
  }
}

/// Global EQ wire index per model key. Studio and Parametric 3 are captured;
/// Cut 24 and Tilt follow the CFW app's list order (checked by the live test).
const _wireIndex = {'studio': 0, 'para3': 1, 'cut24': 2, 'tilt': 3};

List<CfwEqModel> parseCfwEqModels(Map<String, dynamic> json) {
  final models = <CfwEqModel>[
    for (final m in (json['models'] as List).cast<Map<String, dynamic>>())
      if (_wireIndex[m['key']] case final int wire)
        CfwEqModel(
          wireIndex: wire,
          key: m['key'] as String,
          name: m['name'] as String,
          params: [
            for (final p in (m['params'] as List).cast<Map<String, dynamic>>())
              CfwEqParam(
                name: p['name'] as String,
                algId: p['algId'] as int,
                min: p['min'] as num,
                max: p['max'] as num,
                step: p['step'] as num,
                defaultValue: p['defaultValue'] as num,
                kind: (p['kind'] as String?) ?? '',
                mapBase: ((p['map'] as Map?)?['base'] as num?)?.toDouble(),
                mapK: (((p['map'] as Map?)?['k'] as num?) ?? 0).toDouble(),
                mapKNeg: (((p['map'] as Map?)?['k_neg'] as num?) ?? 0)
                    .toDouble(),
                mapOff: (p['map'] as Map?)?['off'] as num?,
                texts: {
                  for (final e in ((p['texts'] as Map?) ?? const {}).entries)
                    e.key as String: e.value as String,
                },
              ),
          ],
        ),
  ]..sort((a, b) => a.wireIndex.compareTo(b.wireIndex));

  return models;
}
