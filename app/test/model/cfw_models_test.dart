import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_model.dart';
import 'package:sonicmaster/model/cfw_models.dart';
import 'package:sonicmaster/model/command_library.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/model/widget_type.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/parameter_values_decoder.dart';

import '../support/test_assets.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('assets/data/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final data = loadTestDataAssets();
  final models = parseCfwModels(_read('cfw_fx_models'), _read('cfw_eq_models'));

  group('frames', () {
    // 39 of the ~6000 captures (two FX2 knobs) carry the float one bit
    // higher than a plain float32 of their value; the captured frame is used
    // for those, so a built frame only has to name the same value.
    test('a knob frame matches every captured one, to the last float bit', () {
      final params = _read('command_library')['parameters'] as Map;
      var checked = 0;

      int floatBits(String frame) {
        final b = collapseFrame(frame)!;

        return ByteData.sublistView(
          Uint8List.fromList(b.sublist(b.length - 4)),
        ).getUint32(0, Endian.little);
      }

      params.forEach((module, byAlg) {
        (byAlg as Map).forEach((alg, byValue) {
          (byValue as Map).forEach((value, frame) {
            final built = CommandLibrary.parameterFrame(
              int.parse(module as String),
              int.parse(alg as String),
              num.parse(value as String),
            );
            final captured = (frame as String).toLowerCase();

            if (built != captured) {
              expect(
                (floatBits(built) - floatBits(captured)).abs(),
                lessThanOrEqualTo(1),
                reason: '$module/$alg/$value',
              );
            }

            checked++;
          });
        });
      });

      expect(checked, greaterThan(6000));
    });

    test('an effect select frame matches the captured stock ones', () {
      final fx = _read('cfw_fx_models')['models'] as List;

      for (final m in fx.cast<Map<String, dynamic>>()) {
        if (m['stockFxIds'] == null) continue;

        final ids = (m['stockFxIds'] as List).cast<int>();
        final effectIds = (m['stockIds'] as List).cast<String>();

        for (var i = 0; i < ids.length; i++) {
          expect(
            CommandLibrary.effectTypeFrame(
              m['block'] as int,
              int.parse(effectIds[i].substring(2), radix: 16),
            ),
            data.commands.effectType(m['block'] as int, ids[i]),
            reason: '${ids[i]}',
          );
        }
      }
    });
  });

  group('models', () {
    test('six delays, five reverbs and four EQs', () {
      int count(int module) => models.where((m) => m.module == module).length;

      expect(count(7), 6);
      expect(count(8), 5);
      expect(count(5), 4);
      expect(cfwModelIds, {for (final m in models) m.def.id});
    });

    test('Studio Delay: its id, effect id and knobs', () {
      final m = models.singleWhere((m) => m.def.name == 'Studio Delay');

      expect(m.def.id, 751);
      expect(m.module, 7);
      expect(m.effectId, 0x0b0000c0);

      final time = m.def.params.singleWhere((p) => p.name == 'Time');
      final trails = m.def.params.singleWhere((p) => p.algId == 7);
      final lowCut = m.def.params.singleWhere((p) => p.name == 'Low Cut');

      expect(time.unit, 'ms');
      expect(time.widgetType, WidgetType.knob);
      // The CFW app names slot 7 "Trails", as its preset files do; on the CFW
      // (0.9.4 on) it holds Off / Trail / Sync / Both, and its Sync bit (2)
      // turns Time into a note division.
      expect(trails.name, 'Trails');
      expect(trails.widgetType, WidgetType.select);
      expect(trails.options, ['Off', 'Trail', 'Sync', 'Both']);
      expect(time.isSynced(const {7: 1}), isFalse);
      expect(time.isSynced(const {7: 2}), isTrue);
      expect(time.isSynced(const {7: 3}), isTrue);
      expect(lowCut.textFor(0), 'Off');
      expect(lowCut.textFor(1), '21Hz');
    });

    test('Studio EQ (module EQ): dB knobs in half steps with their text', () {
      final m = models.singleWhere((m) => m.def.name == 'Studio EQ');

      expect(m.def.id, 504);
      expect(m.module, 5);
      expect(m.effectId, 0x010000c0);

      final bass = m.def.params.singleWhere((p) => p.name == 'Bass');

      expect(bass.step, 0.5);
      expect(bass.textFor(-3.5), '-3.5dB');
    });
  });

  group('loaded data', () {
    test('the models are effects with a select command', () {
      expect(data.effects.byId(751)?.name, 'Studio Delay');
      expect(
        data.commands.effectType(7, 751),
        CommandLibrary.effectTypeFrame(7, 0x0b0000c0),
      );
      expect(data.commands.effectIdsFor(8), contains(854));
    });

    test('a knob no capture has gets a built frame', () {
      expect(
        data.commands.parameterCommand(7, 7, '1'),
        CommandLibrary.parameterFrame(7, 7, 1),
      );
      expect(
        data.commands.parameterCommand(5, 0, '-3.5'),
        CommandLibrary.parameterFrame(5, 0, -3.5),
      );
      // The upstream capture for RVB knob 5 = 4 carried 2.0; it was dropped.
      expect(
        data.commands.parameterCommand(8, 5, '4'),
        CommandLibrary.parameterFrame(8, 5, 4),
      );
    });

    test('the pedal\'s preset dump names them (signatures)', () {
      expect(data.signatures.byModule[7]!.signatureToFxId['0C00'], 751);
      expect(data.signatures.byModule[8]!.signatureToFxId['0C03'], 854);
      expect(data.signatures.byModule[5]!.signatureToFxId['0A0C02'], 506);
      expect(data.signatures.byModule[7]!.signatureToFxId['0101'], 717);
    });

    test('Float and Shake, from the CFW app data, are delays', () {
      expect(data.effects.byId(717)?.name, 'Float');
      expect(data.commands.effectType(7, 718), isNotNull);
    });

    test('offered only on a CFW Pocket Master', () {
      List<int> ids({required bool isCfw}) =>
          data.capabilities.availableEffectIds(
            data.commands,
            DeviceModel.pocketMaster,
            7,
            isCfw: isCfw,
          );

      expect(ids(isCfw: true), containsAll([751, 756, 717]));
      expect(ids(isCfw: false), isNot(contains(751)));
    });
  });

  test('a knob value the lookup table lacks decodes from its float', () {
    for (final e in data.parameters.valueLookup.entries) {
      expect(
        ParameterValuesDecoder.floatOfBlock(e.key),
        e.value,
        reason: e.key,
      );
    }
  });

  test('a community preset with CFW models imports', () {
    final imp = importedPresetFromJson({
      'version': '1.0',
      'ampMode': 'Normal',
      'modules': {
        'EQ': {
          'enabled': true,
          'effect': 'Studio EQ',
          'parameters': {
            'Low Cut': 12,
            'Bass': 0.5,
            'Mid Freq': 4,
            'Mid': -3.5,
            'Q': 0,
            'Treble': -8.5,
            'High Cut': 100,
            'VOL': 75,
          },
        },
        'DLY': {
          'enabled': true,
          'effect': 'Tape Echo',
          'parameters': {
            'Mix': 30,
            'Time': 350,
            'F.Back': 40,
            'Age': 86,
            'Wow': 61,
            'Tone': -25,
            'Duck': 0,
            'Trails': 1,
          },
        },
      },
      'signalChain': ['EQ', 'DLY'],
    }, data);

    expect(imp.selectedEffects, {5: 504, 7: 752});
    expect(imp.parameters[5]?[0], 0.5);
    expect(imp.parameters[7]?[7], 1);
    expect(imp.warnings, isEmpty);
  });

  group('tempo sync on import', () {
    Map<String, dynamic> dly(String effect, Map<String, num> params) => {
      'version': '1.0',
      'ampMode': 'Normal',
      'modules': {
        'DLY': {'enabled': true, 'effect': effect, 'parameters': params},
      },
      'signalChain': ['DLY'],
    };

    test('a synced stock delay keeps its division in Time', () {
      final imp = importedPresetFromJson(
        dly('Analog', {'Mix': 30, 'Time': 4, 'F.Back': 40, 'Sync': 1}),
        data,
      );

      expect(imp.parameters[7]?[1], 4);
      expect(imp.warnings.where((w) => w.contains('Time')), isEmpty);
    });

    test('a CFW delay synced through Trails (Both = 3) too', () {
      final imp = importedPresetFromJson(
        dly('Studio Delay', {
          'Mix': 60,
          'Time': 4,
          'F.Back': 74,
          'Low Cut': 0,
          'High Cut': 39,
          'Mod': 0,
          'Duck': 0,
          'Trails': 3,
        }),
        data,
      );

      expect(imp.parameters[7]?[1], 4);
      expect(imp.parameters[7]?[7], 3);
      expect(imp.warnings, isEmpty);
    });

    test('unsynced, Time still clamps to its range', () {
      final imp = importedPresetFromJson(
        dly('Analog', {'Mix': 30, 'Time': 4, 'F.Back': 40, 'Sync': 0}),
        data,
      );

      expect(imp.parameters[7]?[1], 20);
    });
  });
}
