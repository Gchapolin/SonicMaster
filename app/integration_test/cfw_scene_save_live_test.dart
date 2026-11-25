// Live CFW gate: does the pedal's normal Save keep a preset's scenes?
// Uses User preset 50 (chosen by the user): adds an SC1 value on NR, saves,
// reloads and reads the scenes; then removes it, saves again (same name) and
// checks the preset is back to no scene on NR. Ends on User preset 1.
// Results go to <app tmp>/cfw_save.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/name_dump_decoder.dart';
import 'package:sonicmaster/protocol/preset_name_codec.dart';
import 'package:sonicmaster/protocol/save_preset_frame.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Save keeps scenes (User preset 50)', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_save.txt');

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

      final data = await DataAssets.load();
      final service = DeviceService(UniversalBleTransport())..startListening();

      await service.connect(target: pedal);
      await service.enterEditSession();

      const wait = Duration(seconds: 4);
      Future<void> pause([int ms = 600]) =>
          Future<void>.delayed(Duration(milliseconds: ms));
      Future<bool> load(int n) async {
        final ok = await service.sendAndAwaitAck(
          data.commands.presetSelect(.user, n)!,
          timeout: wait,
        );

        await pause(900);

        return ok;
      }

      Future<List<SceneRecord>> scenes() async {
        final hex = await service.requestSceneRecords(timeout: wait);

        return hex == null ? const [] : decodeSceneRecordsFrame(hex);
      }

      String show(List<SceneRecord> rs) =>
          rs.map((r) => 'm${r.module} sc1=${r.sc1} sc2=${r.sc2}').join(' | ');

      String? namesHex;

      for (var i = 0; i < 3 && namesHex == null; i++) {
        namesHex = await service.requestPresetNames(
          timeout: const Duration(seconds: 6),
        );
      }

      final name = namesHex == null
          ? null
          : decodePresetNames(namesHex, data.characters)[const PresetRef(
              .user,
              50,
            )];

      log('P50 name=${name == null ? 'UNKNOWN' : '"$name"'}');
      if (name == null) {
        log('ABORT: could not read the name, nothing saved');

        return;
      }

      final save = SavePresetFrame(
        PresetNameCodec(data.characters),
      ).build(name: name, presetNumber: 50);

      log('LOAD P50 ack=${await load(50)}');

      final before = await scenes();

      log('SCENES before: ${show(before)}');
      if (before.any((r) => r.module == 0)) {
        log('ABORT: NR already has scene data on P50, nothing saved');

        return;
      }

      await service.sendFrame(
        buildSceneRecordFrame(const SceneRecord(module: 0, sc1: {0: 23})),
      );
      await pause();
      log('SAVE 1 ack=${await service.sendAndAwaitAck(save, timeout: wait)}');
      await pause(1200);
      log('LOAD P49 ack=${await load(49)}');
      log('LOAD P50 ack=${await load(50)}');

      final saved = await scenes();

      log('SCENES after save+reload: ${show(saved)}');
      log(
        'SAVE KEEPS SCENES=${saved.any((r) => r.module == 0 && r.sc1[0] == 23.0)}',
      );

      // Put P50 back: remove the NR scene data and save again.
      await service.sendFrame(clearSceneRecordFrame(0));
      await pause();
      log('SAVE 2 ack=${await service.sendAndAwaitAck(save, timeout: wait)}');
      await pause(1200);
      log('LOAD P49 ack=${await load(49)}');
      log('LOAD P50 ack=${await load(50)}');

      final restored = await scenes();

      log('SCENES after restore: ${show(restored)}');
      log('RESTORED=${!restored.any((r) => r.module == 0)}');
      log('LOAD P01 ack=${await load(1)}');
      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
