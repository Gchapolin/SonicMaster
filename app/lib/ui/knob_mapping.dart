import '../model/effect_definition.dart';
import '../model/effect_parameter.dart';
import '../model/slider_nudge.dart';

/// The effect's knob and EQ band params drawn on its piece (a graphic EQ's
/// bands are its sliders), in the effect's order (the ones the pedal's
/// firmware, [isCfw], has).
List<EffectParameter> pieceKnobs(EffectDefinition def, {bool isCfw = false}) =>
    [
      for (final p in def.paramsFor(isCfw: isCfw))
        if (p.widgetType == .knob || p.widgetType == .eqBand) p,
    ];

/// [v] (the pedal's value) as a piece knob position, 0..100, clamped to the
/// param's range.
double toPieceValue(EffectParameter p, num v) {
  final min = p.min ?? 0;
  final max = p.max ?? 100;

  if (max <= min) return 0;

  return (v.clamp(min, max) - min) / (max - min) * 100;
}

/// A piece knob position [v] (0..100) as the param's value: rounded to its
/// step and kept in min..max.
num fromPieceValue(EffectParameter p, double v) {
  final min = p.min ?? 0;
  final max = p.max ?? 100;
  final step = p.step ?? 1;
  final raw = min + v.clamp(0, 100) / 100 * (max - min);
  final snapped = step > 0 ? min + ((raw - min) / step).round() * step : raw;

  return snapToStep(snapped.clamp(min, max), step);
}

/// [p]'s value [v] as the piece prints it under a graphic EQ slider: the
/// param's own text, else the number, signed when the range is bipolar.
String pieceValueText(EffectParameter p, num v) {
  final text = p.textFor(v);
  if (text != null) return text;

  final n = v == v.roundToDouble() ? v.round().toString() : v.toString();

  return (p.min ?? 0) < 0 && v > 0 ? '+$n' : n;
}
