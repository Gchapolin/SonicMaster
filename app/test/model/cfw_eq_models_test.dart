import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_eq_models.dart';

void main() {
  final models = parseCfwEqModels(
    jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  CfwEqModel named(String n) => models.firstWhere((m) => m.name == n);

  test('four models in the Global EQ wire order', () {
    expect(models.map((m) => (m.wireIndex, m.name)), [
      (0, 'Studio EQ'),
      (1, 'Parametric 3'),
      (2, 'Cut 24'),
      (3, 'Tilt EQ'),
    ]);
  });

  test('dB knobs travel in 0.5 dB steps', () {
    final bass = named('Studio EQ').params.firstWhere((p) => p.name == 'Bass');

    expect(bass.toSlot(2.0), 4);
    expect(bass.toSlot(-12), -24);
    expect(bass.fromSlot(4), 2.0);
  });

  test('model defaults give the captured slots', () {
    expect(named('Parametric 3').defaultSlots(), [0, 0, 0, 0, 0, 50, 33, 40]);
    expect(named('Studio EQ').defaultSlots(), [0, 0, 0, 0, 0, 50, 0, 100]);
  });

  test('value texts come from the data', () {
    final lowCut = named(
      'Studio EQ',
    ).params.firstWhere((p) => p.name == 'Low Cut');
    final bass = named('Studio EQ').params.firstWhere((p) => p.name == 'Bass');

    expect(lowCut.textFor(7), '26Hz');
    expect(lowCut.textFor(0), 'Off');
    expect(bass.textFor(2.0), '+2.0dB');
    expect(bass.textFor(-11.5), '-11.5dB');
  });
}
