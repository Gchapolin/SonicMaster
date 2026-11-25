import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_firmware_variants.dart';
import 'package:sonicmaster/model/cfw_info.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/model/widget_type.dart';

import '../support/test_assets.dart';

/// Capability words of the CFW app's demo profiles: 0.9.6 lacks bit 31
/// (`sbModels097`); 0.9.7 on, and the captured 1.0.2, carry it.
const _caps096 = 0x4fff8f7f;
const _caps097 = 0xcfff8f7f;

CfwInfo _info(int caps, {String version = 'CFW1.0.2', int extra = 0x09cf}) =>
    CfwInfo(
      version: version,
      capabilities: caps,
      settings: const {},
      extraCapabilities: extra,
    );

String _slot6(DataAssets data) => data.effects
    .byId(swellDelayId)!
    .params
    .singleWhere((p) => p.algId == 6)
    .name;

void main() {
  test('with sbModels097, Swell Delay slot 6 is Sens (-50..50)', () {
    final data = loadTestDataAssets();
    final before = data.effects.byId(swellDelayId)!;

    fitCfwModels(data.effects, _info(_caps097));

    final def = data.effects.byId(swellDelayId)!;
    final sens = def.params.singleWhere((p) => p.algId == 6);

    expect(sens.name, 'Sens');
    expect(sens.widgetType, WidgetType.knob);
    expect((sens.min, sens.max, sens.step, sens.defaultValue), (-50, 50, 1, 0));
    expect(sens.texts, isEmpty);
    // Every other knob, and the other delays, as in the data.
    expect(
      [
        for (final p in def.params)
          if (p.algId != 6) p,
      ],
      [
        for (final p in before.params)
          if (p.algId != 6) p,
      ],
    );
    expect(def.name, 'Swell Delay');
    expect(
      data.effects.byId(751)!.params.any((p) => p.name == 'Sens'),
      isFalse,
    );
  });

  test('without it, on stock (null) or on a NAM build, slot 6 is Duck', () {
    final data = loadTestDataAssets();

    for (final info in [
      _info(_caps096),
      null,
      _info(_caps097, version: 'CFW1.0.2-NAM'),
      _info(_caps097, extra: 0x1000),
    ]) {
      fitCfwModels(data.effects, info);
      expect(_slot6(data), 'Duck', reason: info?.version);
    }
  });

  test('a later pedal without the bit gets the data model back', () {
    final data = loadTestDataAssets();
    final original = data.effects.byId(swellDelayId);

    fitCfwModels(data.effects, _info(_caps097));
    fitCfwModels(data.effects, _info(_caps097));
    expect(_slot6(data), 'Sens');

    fitCfwModels(data.effects, null);
    expect(data.effects.byId(swellDelayId), same(original));
  });

  test('a community preset imports Sens by name', () {
    final data = loadTestDataAssets();

    fitCfwModels(data.effects, _info(_caps097));

    final imp = importedPresetFromJson({
      'version': '1.0',
      'modules': {
        'DLY': {
          'enabled': true,
          'effect': 'Swell Delay',
          'parameters': {
            'Mix': 40,
            'Time': 400,
            'F.Back': 40,
            'Swell': 50,
            'Mod': 25,
            'Tone': 0,
            'Sens': -20,
            'Trails': 0,
          },
        },
      },
      'signalChain': ['DLY'],
    }, data);

    expect(imp.parameters[7]?[6], -20);
    expect(imp.warnings, isEmpty);
  });
}
