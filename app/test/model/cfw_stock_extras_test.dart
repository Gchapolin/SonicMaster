import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/decoded_preset_state.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/model/widget_type.dart';

import '../support/test_assets.dart';

/// The CFW's extra knobs on the stock delays and reverbs, as the CFW web app
/// lays them out (cfw_fx_models.json `stockExtraParams`).
void main() {
  final data = loadTestDataAssets();

  List<String> names(int fxId, {required bool isCfw}) => [
    for (final p in data.effects.byId(fxId)!.paramsFor(isCfw: isCfw)) p.name,
  ];

  group('stock delays', () {
    test('stock firmware: as before', () {
      expect(names(707, isCfw: false), [
        'Mix',
        'Time',
        'F.Back',
        'Sync',
        'Trail',
      ]);
      expect(names(702, isCfw: false), ['Mix', 'Time', 'F.Back', 'Trail']);
    });

    test('CFW: Tone / Duck / Trails at 5 / 6 / 7, the slot-4 Trail gone', () {
      expect(names(707, isCfw: true), [
        'Mix',
        'Time',
        'F.Back',
        'Sync',
        'Tone',
        'Duck',
        'Trails',
      ]);
      expect(names(702, isCfw: true), [
        'Mix',
        'Time',
        'F.Back',
        'Tone',
        'Duck',
        'Trails',
      ]);

      final params = data.effects.byId(707)!.paramsFor(isCfw: true);
      final tone = params.singleWhere((p) => p.name == 'Tone');
      final duck = params.singleWhere((p) => p.name == 'Duck');
      final trails = params.singleWhere((p) => p.name == 'Trails');

      expect((tone.algId, tone.min, tone.max), (5, -50, 50));
      expect(tone.textFor(-50), 'Dark 50');
      expect(tone.textFor(0), 'Flat');
      expect(duck.algId, 6);
      expect(duck.textFor(0), 'Off');
      expect((trails.algId, trails.widgetType), (7, WidgetType.toggle));
    });

    test('Sweep keeps 5 / 6 (its sync toggles) and only gains Trails', () {
      expect(names(708, isCfw: true), [...names(708, isCfw: false), 'Trails']);
    });
  });

  group('stock reverbs', () {
    test('CFW: High Cut / Low Cut / Trails at 3 / 6 / 7', () {
      expect(names(805, isCfw: false), ['Mix', 'Decay']);
      expect(names(805, isCfw: true), [
        'Mix',
        'Decay',
        'High Cut',
        'Low Cut',
        'Trails',
      ]);

      final params = data.effects.byId(810)!.paramsFor(isCfw: true);

      expect([for (final p in params) p.algId], [0, 2, 4, 5, 3, 6, 7]);
      expect(params.singleWhere((p) => p.algId == 3).textFor(0), 'Stock');
      expect(params.singleWhere((p) => p.algId == 6).textFor(1), '21Hz');
    });
  });

  group('preset files', () {
    Map<String, dynamic> file(Map<String, dynamic> modules) => {
      'version': '1.0',
      'ampMode': 'Normal',
      'modules': modules,
      'signalChain': modules.keys.toList(),
    };

    test('a community preset keeps the extra knobs (CLNGilmour)', () {
      final imp = importedPresetFromJson(
        file({
          'DLY': {
            'enabled': true,
            'effect': 'Analog',
            'parameters': {
              'Mix': 30,
              'Time': 4,
              'F.Back': 40,
              'Sync': 1,
              'Trail': 50,
              'Tone': -12,
              'Duck': 20,
              'Trails': 1,
            },
          },
          'RVB': {
            'enabled': true,
            'effect': 'Plate 1',
            'parameters': {
              'Mix': 35,
              'Decay': 50,
              'High Cut': 40,
              'Low Cut': 10,
              'Trails': 1,
            },
          },
        }),
        data,
      );

      expect(imp.parameters[7], {
        0: 30,
        1: 4,
        2: 40,
        3: 1,
        4: 50,
        5: -12,
        6: 20,
        7: 1,
      });
      expect(imp.parameters[8], {0: 35, 2: 50, 3: 40, 6: 10, 7: 1});
      expect(imp.warnings, isEmpty);
    });

    test('a stock file has no extra knobs, and no warning for them', () {
      final imp = importedPresetFromJson(
        file({
          'DLY': {
            'enabled': true,
            'effect': 'Analog',
            'parameters': {
              'Mix': 30,
              'Time': 400,
              'F.Back': 40,
              'Sync': 0,
              'Trail': 1,
            },
          },
        }),
        data,
      );

      expect(imp.parameters[7], {0: 30, 1: 400, 2: 40, 3: 0, 4: 1});
      expect(imp.warnings, isEmpty);
    });

    test('export writes the extra knobs only from a CFW pedal', () {
      Map<String, dynamic> dly({required bool isCfw}) =>
          (presetToJson(
                    state: DecodedPresetState(
                      moduleStates: const {'DLY': true},
                      chainOrder: const ['DLY'],
                      isCloneMode: false,
                      presetVolume: 75,
                      presetBpm: 120,
                    ),
                    selected: const {7: 707},
                    params: const {
                      7: {0: 30, 1: 400, 2: 40, 3: 0, 4: 0, 5: -3, 6: 0, 7: 1},
                    },
                    data: data,
                    isCfw: isCfw,
                  )['modules']
                  as Map)['DLY']['parameters']
              as Map<String, dynamic>;

      expect(dly(isCfw: false).keys, [
        'Mix',
        'Time',
        'F.Back',
        'Sync',
        'Trail',
      ]);
      // As the CFW app's own export: the slot-4 Trail stays in the file.
      expect(dly(isCfw: true), {
        'Mix': 30,
        'Time': 400,
        'F.Back': 40,
        'Sync': 0,
        'Trail': 0,
        'Tone': -3,
        'Duck': 0,
        'Trails': 1,
      });
    });
  });
}
