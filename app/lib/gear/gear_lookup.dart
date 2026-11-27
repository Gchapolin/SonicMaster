import 'gear_specs.dart';

export 'gear_specs.dart' show GearKind;

/// The piece drawn for [model]; a [GenericSpec] when the tables lack it.
GearSpec gearFor(String model, GearKind kind) =>
    switch (kind) {
      GearKind.pedal => pedalSpecs[model],
      GearKind.amp => ampSpecs[model],
      GearKind.cab => cabSpecs[model],
    } ??
    GenericSpec(kind);

/// Physical module id: 3 is the amp, 4 the cab (IR), the rest are pedals.
GearKind gearKindForModule(int physId) => switch (physId) {
  3 => GearKind.amp,
  4 => GearKind.cab,
  _ => GearKind.pedal,
};

/// Whether [model]'s piece draws knobs that can be turned: cabs and the wah
/// family draw none, so their knob params must live in the panel instead.
bool pieceDrawsKnobs(String model, GearKind kind) =>
    switch (gearFor(model, kind)) {
      CabSpec() => false,
      GenericSpec(kind: GearKind.cab) => false,
      PedalSpec(family: PedalFamily.wah) => false,
      _ => true,
    };

/// The box [model]'s mini piece fits in on the pedalboard (prototype
/// N_Principal fitW / fitH): amp 118x76, cab 88x92, pedal 66x114. The
/// landscape pedals (rack, studio, tape: twice as wide as tall or near it)
/// take the amp's box, so they read at the size of their neighbours instead
/// of a sliver across the pedal's.
({double width, double height}) pedalboardSlot(String? model, GearKind kind) =>
    switch (kind) {
      GearKind.amp => (width: 118, height: 76),
      GearKind.cab => (width: 88, height: 92),
      GearKind.pedal => switch (model == null ? null : pedalSpecs[model]) {
        PedalSpec(
          family: PedalFamily.rack || PedalFamily.studio || PedalFamily.tape,
        ) =>
          (width: 118, height: 76),
        _ => (width: 66, height: 114),
      },
    };
