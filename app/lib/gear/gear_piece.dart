import 'package:flutter/widgets.dart';

import 'amp_piece.dart';
import 'cab_piece.dart';
import 'gear_lookup.dart';
import 'gear_specs.dart';
import 'pedal_piece.dart';

export 'gear_lookup.dart' show GearKind;

const _grey = Color(0xFF6E6E6E);
const _ink = Color(0xFFE9E9E9);

const _genericPedal = PedalSpec(PedalFamily.std, _grey, _ink, KnobStyle.black, [
  '',
  '',
  '',
]);
const _genericAmp = AmpSpec(
  true,
  _grey,
  Color(0xFF3A3A3A),
  AmpPanel.silver,
  KnobStyle.black,
  false,
  ['', '', '', ''],
);
const _genericCab = CabSpec(
  2,
  12,
  _grey,
  Color(0xFF3A3A3A),
  false,
  false,
  false,
);

/// Plain grey placeholder for a model with no table entry, drawn with the
/// regular painters.
class GenericPiece extends StatelessWidget {
  const GenericPiece({super.key, required this.spec, required this.model});

  final GenericSpec spec;
  final String model;

  @override
  Widget build(BuildContext context) => switch (spec.kind) {
    GearKind.pedal => PedalPiece(spec: _genericPedal, model: model),
    GearKind.amp => AmpPiece(spec: _genericAmp, model: model),
    GearKind.cab => CabPiece(spec: _genericCab, model: model),
  };
}

/// Any piece for [model], scaled to fit inside [fit]. [knobNames], when given,
/// replaces the spec's knob names (pedals and amps).
class GearPiece extends StatelessWidget {
  const GearPiece({
    super.key,
    required this.model,
    required this.kind,
    required this.fit,
    this.values,
    this.onKnob,
    this.onSwitch,
    this.lit = true,
    this.knobNames,
  });

  final String model;
  final GearKind kind;
  final Size fit;
  final List<double?>? values;
  final ValueChanged<(int, double)>? onKnob;
  final VoidCallback? onSwitch;
  final bool lit;
  final List<String>? knobNames;

  Widget _piece() {
    final names = knobNames;
    return switch (gearFor(model, kind)) {
      final PedalSpec s => PedalPiece(
        spec: names == null
            ? s
            : PedalSpec(s.family, s.body, s.label, s.knob, names),
        model: model,
        values: values,
        onKnob: onKnob,
        onSwitch: onSwitch,
        lit: lit,
      ),
      final AmpSpec s => AmpPiece(
        spec: names == null
            ? s
            : AmpSpec(
                s.isHead,
                s.tolex,
                s.grille,
                s.panel,
                s.knob,
                s.piping,
                names,
              ),
        model: model,
        values: values,
        onKnob: onKnob,
        onSwitch: onSwitch,
        lit: lit,
      ),
      final CabSpec s => CabPiece(spec: s, model: model),
      final GenericSpec s => GenericPiece(spec: s, model: model),
    };
  }

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: fit,
    child: FittedBox(fit: BoxFit.contain, child: _piece()),
  );
}
