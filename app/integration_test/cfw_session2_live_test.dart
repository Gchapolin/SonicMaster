// Live CFW gate for the slot names, EXP A-D and the tuner — requires a Pocket
// Master on the community custom firmware, advertising over BLE and free.
// Writes each step's result to <app tmp>/cfw_live2.txt (read it back with
// `xcrun devicectl device copy from --domain-type appDataContainer`). Saves
// nothing on the pedal and restores what it changes (EXP block, A4, output,
// tuner closed).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/model/tuner_reading.dart';
import 'package:sonicmaster/protocol/cfw_exp_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/cfw_slot_names_codec.dart';
import 'package:sonicmaster/protocol/cfw_tuner_codec.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('slot names, EXP and tuner on the real pedal', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_live2.txt');

    out.writeAsStringSync('START ${DateTime.now().toIso8601String()}\n');
    void log(String line) =>
        out.writeAsStringSync('$line\n', mode: FileMode.append);

    try {
      await initTransports();

      final pedal = (await enumerateBleDevices())
          .map((d) => d.name)
          .firstWhere((n) => n.contains('Pocket Master'), orElse: () => '');

      log('SCAN ${pedal.isEmpty ? 'no pedal found' : pedal}');
      if (pedal.isEmpty) return;

      final service = DeviceService(UniversalBleTransport())..startListening();

      await service.connect(target: pedal);
      const wait = Duration(seconds: 3);
      Future<void> pause([int ms = 400]) =>
          Future<void>.delayed(Duration(milliseconds: ms));

      final cfwHex = await service.requestCfwSettings(timeout: wait);
      final cfw = cfwHex == null ? null : decodeCfwSettingsFrame(cfwHex);

      log('CFW ${cfw?.version} settings=${cfw?.settings}');
      log(
        'MIDI map=${cfw?.midiMap} channel=${cfw?.midiChannel} '
        'sameAgain=${cfw?.sameAgain} tempoScope=${cfw?.tempoScope} '
        'options=${cfw?.customMapOptions} drumSync=${cfw?.drumSync}',
      );

      // --- Slot names.
      for (final register in [cfwIrNamesRegister, cfwProfileNamesRegister]) {
        final hex = await service.requestCfwSlotNames(register, timeout: wait);

        log(
          'NAMES 0x${register.toRadixString(16)} '
          '${hex == null ? 'no answer' : decodeCfwSlotNames(hex, register)}',
        );
        log('NAMES raw len=${hex?.length} $hex');
      }

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
