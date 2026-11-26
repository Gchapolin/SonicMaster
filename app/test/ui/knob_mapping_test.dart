import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/effect_definition.dart';
import 'package:sonicmaster/model/effect_parameter.dart';
import 'package:sonicmaster/model/widget_type.dart';
import 'package:sonicmaster/ui/knob_mapping.dart';

EffectParameter _p(
  String name,
  WidgetType type, {
  num? min,
  num? max,
  num? step,
  bool? onlyOnCfw,
}) => EffectParameter(
  name: name,
  algId: name.codeUnitAt(0),
  defaultValue: 0,
  widgetType: type,
  min: min,
  max: max,
  step: step,
  onlyOnCfw: onlyOnCfw,
);

void main() {
  test('knob values map both ways', () {
    final p = _p('X', .knob, min: 0, max: 10, step: 0.5);

    // Out of range from the pedal: shown clamped.
    expect(toPieceValue(p, 15), 100);
    expect(toPieceValue(p, -2), 0);
    expect(toPieceValue(p, 2.5), 25);
    // Sent rounded to the step, inside min..max.
    expect(fromPieceValue(p, 33), 3.5);
    expect(fromPieceValue(p, 140), 10);
    expect(fromPieceValue(p, -5), 0);
  });

  test('an offset range with an integer step sends whole numbers', () {
    final p = _p('Y', .knob, min: -12, max: 12, step: 1);

    expect(toPieceValue(p, 0), 50);
    expect(fromPieceValue(p, 52), 0);
    expect(fromPieceValue(p, 52), isA<int>());
    // A fractional step keeps one decimal (no 0.30000000000000004).
    expect(fromPieceValue(_p('Z', .knob, min: 0, max: 1, step: 0.1), 31), 0.3);
  });

  test('no range defaults to 0..100 step 1', () {
    final p = _p('W', .knob);

    expect(toPieceValue(p, 40), 40);
    expect(fromPieceValue(p, 40.4), 40);
  });

  test('pieceKnobs keeps the knob params, in the effect order', () {
    final def = EffectDefinition(
      id: 1,
      name: 'Fx',
      descriptionEn: '',
      params: [
        _p('A', .knob),
        _p('B', .toggle),
        _p('C', .knob),
        _p('D', .select),
        _p('E', .eqBand),
        _p('F', .knob, onlyOnCfw: true),
      ],
    );

    expect(pieceKnobs(def).map((p) => p.name), ['A', 'C']);
    expect(pieceKnobs(def, isCfw: true).map((p) => p.name), ['A', 'C', 'F']);
  });
}
