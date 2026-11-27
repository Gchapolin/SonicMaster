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
  Tolex.grey,
  Grille.black,
  AmpPanel.silver,
  KnobStyle.black,
  false,
  ['', '', '', ''],
);
const _genericCab = CabSpec(
  2,
  12,
  Tolex.grey,
  Grille.black,
  false,
  false,
  false,
);

/// Plain grey placeholder for a model with no table entry, drawn with the
/// regular painters. [knobNames] (non-empty) sets the knob count and labels;
/// otherwise the placeholder count is used.
class GenericPiece extends StatelessWidget {
  const GenericPiece({
    super.key,
    required this.spec,
    required this.model,
    this.values,
    this.onKnob,
    this.onSwitch,
    this.lit = true,
    this.knobNames,
  });

  final GenericSpec spec;
  final String model;
  final List<double?>? values;
  final ValueChanged<(int, double)>? onKnob;
  final VoidCallback? onSwitch;
  final bool lit;
  final List<String>? knobNames;

  @override
  Widget build(BuildContext context) {
    final names = knobNames == null || knobNames!.isEmpty ? null : knobNames;
    return switch (spec.kind) {
      GearKind.pedal => PedalPiece(
        spec: PedalSpec(
          _genericPedal.family,
          _genericPedal.body,
          _genericPedal.label,
          _genericPedal.knob,
          names ?? _genericPedal.knobNames,
        ),
        model: model,
        values: values,
        onKnob: onKnob,
        onSwitch: onSwitch,
        lit: lit,
      ),
      GearKind.amp => AmpPiece(
        spec: AmpSpec(
          _genericAmp.isHead,
          _genericAmp.tolex,
          _genericAmp.grille,
          _genericAmp.panel,
          _genericAmp.knob,
          _genericAmp.piping,
          names ?? _genericAmp.knobNames,
        ),
        model: model,
        values: values,
        onKnob: onKnob,
        onSwitch: onSwitch,
        lit: lit,
      ),
      GearKind.cab => CabPiece(spec: _genericCab, model: model),
    };
  }
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
    this.valueTexts,
  });

  final String model;
  final GearKind kind;
  final Size fit;
  final List<double?>? values;
  final ValueChanged<(int, double)>? onKnob;
  final VoidCallback? onSwitch;
  final bool lit;
  final List<String>? knobNames;

  /// Each knob's value as text, for pieces that print it (graphic EQ).
  final List<String>? valueTexts;

  Widget _piece() {
    // An empty list would make the pedal layout divide by zero: use the spec.
    final names = knobNames == null || knobNames!.isEmpty ? null : knobNames;
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
        valueTexts: valueTexts,
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
      final GenericSpec s => GenericPiece(
        spec: s,
        model: model,
        values: values,
        onKnob: onKnob,
        onSwitch: onSwitch,
        lit: lit,
        knobNames: names,
      ),
    };
  }

  // Its own layer: dragging a knob repaints this piece, not its neighbours.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.fromSize(
      size: fit,
      child: FittedBox(fit: BoxFit.contain, child: _piece()),
    ),
  );
}
