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
