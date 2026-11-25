import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_model.dart';
import 'package:sonicmaster/model/command_library.dart';
import 'package:sonicmaster/model/device_capabilities.dart';

void main() {
  final caps = DeviceCapabilities.fromJson(
    jsonDecode(File('assets/data/device_capabilities.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final commands = CommandLibrary.fromJson(
    jsonDecode(File('assets/data/command_library.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const modules = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  group('detect', () {
    test('USB port names map to models, case-insensitively', () {
      expect(
        caps.detect(name: 'Smart Box MIDI 1', kind: .usb),
        DeviceModel.smartBox,
      );
      expect(
        caps.detect(name: 'SONICAKE POCKET MASTER', kind: .usb),
        DeviceModel.pocketMaster,
      );
    });

    test('BLE advertised names map to models', () {
      expect(
        caps.detect(name: 'Smart Box BLE', kind: .ble),
        DeviceModel.smartBox,
      );
      expect(
        caps.detect(name: 'Pocket Master BLE', kind: .ble),
        DeviceModel.pocketMaster,
      );
    });

    test('a null or unrecognized name fails open to unknown', () {
      expect(caps.detect(name: null, kind: .usb), DeviceModel.unknown);
      expect(
        caps.detect(name: 'Some Other Pedal', kind: .ble),
        DeviceModel.unknown,
      );
    });
  });

  group('availableEffectIds', () {
    test('smartBox and unknown pass through the full pickable set', () {
      for (final moduleId in modules) {
        // Slots 6-10 of the User IRs and User Profiles exist only on the CFW.
        final all = commands
            .effectIdsFor(moduleId)
            .where((id) => !cfwOnlySlotIds.contains(id))
            .toList();

        expect(caps.availableEffectIds(commands, .smartBox, moduleId), all);
        expect(caps.availableEffectIds(commands, .unknown, moduleId), all);
      }
    });

    test('pocketMaster narrows the amp list to 301-322', () {
      final amps = caps.availableEffectIds(commands, .pocketMaster, 3);

      expect(amps, commands.effectIdsFor(3).where((id) => id <= 322).toList());
      expect(amps, isNot(contains(323)));
      expect(amps, isNot(contains(338)));
    });

    test('pocketMaster drops the Smart Box-only mods, delays, and cab', () {
      expect(
        caps.availableEffectIds(commands, .pocketMaster, 1),
        isNot(contains(120)), // Phaser ST (FX1)
      );
      expect(
        caps.availableEffectIds(commands, .pocketMaster, 6),
        isNot(contains(601)), // BBD Phaser (FX2)
      );
      expect(
        caps.availableEffectIds(commands, .pocketMaster, 7),
        isNot(contains(716)), // Echo (DLY)
      );
      expect(
        caps.availableEffectIds(commands, .pocketMaster, 4),
        isNot(contains(421)), // Bass 4x10 (IR)
      );
    });

    test('the pocketMaster manifest never drifts past the command library', () {
      for (final moduleId in modules) {
        final all = commands.effectIdsFor(moduleId).toSet();
        final pm = caps.availableEffectIds(commands, .pocketMaster, moduleId);

        expect(
          pm.every(all.contains),
          isTrue,
          reason: 'module $moduleId manifest id absent from command library',
        );

        final sorted = [...pm]..sort();

        expect(pm, sorted, reason: 'module $moduleId not sorted');
      }
    });
  });

  group('CFW', () {
    test('User IR and User Profile slots 6-10 appear only with the CFW', () {
      for (final model in DeviceModel.values) {
        final ir = caps.availableEffectIds(commands, model, 4);
        final clone = caps.availableEffectIds(commands, model, 9);

        expect(ir, isNot(contains(422)), reason: '$model');
        expect(clone, contains(905), reason: '$model');
        expect(clone, isNot(contains(906)), reason: '$model');

        expect(
          caps.availableEffectIds(commands, model, 4, isCfw: true),
          containsAll([416, 420, 422, 426]),
          reason: '$model',
        );
        expect(
          caps.availableEffectIds(commands, model, 9, isCfw: true),
          containsAll([901, 905, 906, 910]),
          reason: '$model',
        );
      }
    });

    test('a CFW Pocket Master also gets the Smart Box amps', () {
      final stock = caps.availableEffectIds(commands, .pocketMaster, 3);
      final cfw = caps.availableEffectIds(
        commands,
        .pocketMaster,
        3,
        isCfw: true,
      );

      expect(stock, isNot(contains(323)));
      expect(cfw, containsAll(stock));
      expect(cfw, containsAll([323, 329, 338]));
      expect(cfw.length, stock.length + 16);
    });

    test('delays and modulations are added, unknown ids are not', () {
      final dly = caps.availableEffectIds(
        commands,
        .pocketMaster,
        7,
        isCfw: true,
      );

      expect(dly, containsAll([710, 716]));
      expect(dly, isNot(contains(717))); // no command data for it yet
      expect(
        caps.availableEffectIds(commands, .pocketMaster, 1, isCfw: true),
        contains(601),
      );
    });

    test('the flag changes nothing for a Smart Box', () {
      expect(
        caps.availableEffectIds(commands, .smartBox, 3, isCfw: true),
        caps.availableEffectIds(commands, .smartBox, 3),
      );
    });
  });
}
