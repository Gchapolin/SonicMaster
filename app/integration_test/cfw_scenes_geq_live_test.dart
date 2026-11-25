// Live CFW gate for the Global EQ and the scenes — requires a Pocket Master on
// the community custom firmware, advertising over BLE and free.
// Writes each step's result to <app tmp>/cfw_live.txt (read it back with
// `xcrun devicectl device copy from --domain-type appDataContainer`), so it
// needs no console or debugger. Saves nothing on the pedal and restores what
// it changes.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/cfw_global_eq.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_geq_codec.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Global EQ and scenes round-trip on the real pedal', (
    tester,
  ) async {
    final out = File('${Directory.systemTemp.path}/cfw_live.txt');

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
      Future<void> pause() =>
          Future<void>.delayed(const Duration(milliseconds: 400));

      final cfwHex = await service.requestCfwSettings(timeout: wait);
      final cfw = cfwHex == null ? null : decodeCfwSettingsFrame(cfwHex);

      log(
        'CFW ${cfw?.version} theme=${cfw?.theme} scene=${cfw?.settings[0x10]}',
      );

      // --- Global EQ: confirm the Cut 24 / Tilt model indices, then restore.
      Future<CfwGlobalEq?> readEq() async {
        final hex = await service.requestGlobalEq(timeout: wait);

        return hex == null ? null : decodeGlobalEqFrame(hex);
      }

      final eq0 = await readEq();

      log(
        'GEQ original on=${eq0?.isOn} model=${eq0?.model} slots=${eq0?.slots}',
      );
      if (eq0 != null) {
        for (final (model, slots) in [
          (2, [1, 0, 0, 0, 0, 50, 38, 69]),
          (3, [0, 0, 0, 0, 0, 50, 0, 100]),
        ]) {
          await service.sendFrame(
            buildGlobalEqFrame(
              CfwGlobalEq(isOn: eq0.isOn, model: model, slots: slots),
            ),
          );
          await pause();

          final back = await readEq();

          log(
            'GEQ wrote model=$model read model=${back?.model} slots=${back?.slots}',
          );
        }
        await service.sendFrame(buildGlobalEqFrame(eq0));
        await pause();

        final restored = await readEq();

        log(
          'GEQ restored=${restored?.model == eq0.model && '${restored?.slots}' == '${eq0.slots}' && restored?.isOn == eq0.isOn}',
        );
      }

      // --- Scenes on NR (module 0): add, set an SC1 value, read, clear.
      Future<List<SceneRecord>> readScenes() async {
        final hex = await service.requestSceneRecords(timeout: wait);

        return hex == null ? const [] : decodeSceneRecordsFrame(hex);
      }

      String show(List<SceneRecord> rs) => rs
          .map(
            (r) =>
                'm${r.module} sc1=${r.sc1} sc2=${r.sc2} on=${r.sc1On}/${r.sc2On}',
          )
          .join(' | ');

      final before = await readScenes();

      log('SCENES before: ${show(before)}');

      if (before.any((r) => r.module == 0)) {
        log('SCENES skipped: NR already has scene data on this preset');
      } else {
        await service.sendFrame(
          buildSceneRecordFrame(const SceneRecord(module: 0, sc1: {0: 23})),
        );
        await pause();
        log('SCENES after write: ${show(await readScenes())}');

        await service.sendFrame(clearSceneRecordFrame(0));
        await pause();

        final after = await readScenes();

        log('SCENES after clear: ${show(after)}');
        log('SCENES clear works=${!after.any((r) => r.module == 0)}');
      }

      final sceneHex = await service.requestCurrentScene(timeout: wait);

      log(
        'SCENE current=${sceneHex == null ? null : decodeCurrentSceneFrame(sceneHex)}',
      );

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
