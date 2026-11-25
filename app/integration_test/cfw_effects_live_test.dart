// Live CFW gate: does a CFW Pocket Master take the Smart Box effects the app
// now offers it? Selects one per module on User preset 50 WITHOUT saving,
// reads the state back, then reloads the preset (discarding the edits) and
// ends on User preset 1. Results go to <app tmp>/cfw_fx.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/protocol/selected_effects_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CFW takes Smart Box effects', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_fx.txt');

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
      Future<void> pause([int ms = 700]) =>
          Future<void>.delayed(Duration(milliseconds: ms));
      Future<Map<int, int>> selected() async {
        String? dump;

        for (var i = 0; i < 3 && dump == null; i++) {
          dump = await service.requestStateDump(timeout: wait);
        }

        return dump == null
            ? const {}
            : SelectedEffectsDecoder(data.signatures).decode(dump);
      }

      Future<bool> load(int n) async {
        final ok = await service.sendAndAwaitAck(
          data.commands.presetSelect(.user, n)!,
          timeout: wait,
        );

        await pause(900);

        return ok;
      }

      log('LOAD P50 ack=${await load(50)}');

      final before = await selected();

      log('BEFORE $before');

      // module -> a Smart Box effect the CFW adds to the Pocket Master.
      for (final (module, fx) in [(3, 329), (7, 716), (1, 601)]) {
        final frame = data.commands.effectType(module, fx);

        if (frame == null) {
          log('m$module fx$fx: no command');
          continue;
        }

        final ack = await service.sendAndAwaitAck(frame, timeout: wait);

        await pause();

        final now = await selected();

        log(
          'm$module want=$fx ack=$ack read=${now[module]} ok=${now[module] == fx}',
        );
      }

      // Discard: reload the preset from flash.
      log('LOAD P49 ack=${await load(49)}');
      log('LOAD P50 ack=${await load(50)}');

      final after = await selected();

      log('AFTER $after');
      log('DISCARDED=${'$after' == '$before'}');
      log('LOAD P01 ack=${await load(1)}');
      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
