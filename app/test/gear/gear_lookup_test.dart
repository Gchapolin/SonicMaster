import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_lookup.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
import 'package:sonicmaster/model/data_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every effect in the app has its own piece', () async {
    final data = await DataAssets.load();
    final missing = <String>[];

    void check(int module, String name) {
      final kind = gearKindForModule(module);

      if (gearFor(name, kind) is GenericSpec) missing.add('$module:$name');
    }

    // Chain modules 0-8; module 9 (Clone) is not a piece.
    for (var m = 0; m < 9; m++) {
      for (final id in data.commands.effectIdsFor(m)) {
        final def = data.effects.byId(id);

        if (def != null) check(m, def.name);
      }
    }

    expect(missing, isEmpty);
  });

  test('an unknown model gets a generic piece', () {
    expect(gearFor('Nova Coisa', GearKind.pedal) is GenericSpec, true);
  });

  test('module to kind', () {
    expect(gearKindForModule(3), GearKind.amp);
    expect(gearKindForModule(4), GearKind.cab);
    expect(gearKindForModule(5), GearKind.pedal);
  });
}
