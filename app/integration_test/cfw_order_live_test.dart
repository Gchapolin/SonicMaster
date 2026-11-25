// Live CFW gate for the preset order — requires a Pocket Master on the
// community custom firmware, advertising over BLE and free. Swaps P50 and P49
// and swaps them back; writes each step to <app tmp>/cfw_live3.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/protocol/cfw_preset_order_codec.dart';
import 'package:sonicmaster/protocol/name_dump_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preset order round-trip on the real pedal', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_live3.txt');

    out.writeAsStringSync('START ${DateTime.now().toIso8601String()}\n');
    void log(String line) =>
        out.writeAsStringSync('$line\n', mode: FileMode.append);

    try {
      await initTransports();

      final data = await DataAssets.load();
      final pedal = (await enumerateBleDevices())
          .map((d) => d.name)
          .firstWhere((n) => n.contains('Pocket Master'), orElse: () => '');

      log('SCAN ${pedal.isEmpty ? 'no pedal found' : pedal}');
      if (pedal.isEmpty) return;

      final service = DeviceService(UniversalBleTransport())..startListening();

      await service.connect(target: pedal);
      const wait = Duration(seconds: 4);

      Future<PresetOrder?> readOrder() async {
        final hex = await service.requestPresetOrder(timeout: wait);

        return hex == null ? null : decodePresetOrderFrame(hex);
      }

      Future<String> tailNames() async {
        final dump = await service.requestPresetNames(timeout: wait);

        if (dump == null) return 'no names';

        final names = decodePresetNames(dump, data.characters);

        return [
          for (var n = 47; n <= 50; n++) 'P$n=${names[PresetRef(.user, n)]}',
        ].join(' ');
      }

      Future<bool> write(PresetOrder from, List<int> entries) async {
        for (final f in buildPresetOrderFrames(
          token: from.token,
          entries: entries,
        )) {
          if (!await service.sendAndAwaitAck(
            f,
            timeout: const Duration(seconds: 2),
          )) {
            return false;
          }
        }

        return true;
      }

      final before = await readOrder();

      log(
        'ORDER before token=0x${before?.token.toRadixString(16)} '
        'identity=${before?.isIdentity} tail=${before?.entries.sublist(46)}',
      );
      log('NAMES before ${await tailNames()}');
      if (before == null) return;

      final moved = movePreset(before.entries, from: 49, to: 48);

      log('WRITE swap acked=${await write(before, moved)}');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final after = await readOrder();

      log(
        'ORDER after token=0x${after?.token.toRadixString(16)} '
        'tail=${after?.entries.sublist(46)}',
      );
      log('NAMES after ${await tailNames()}');
      if (after == null) return;

      log('WRITE restore acked=${await write(after, before.entries)}');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final restored = await readOrder();

      log(
        'ORDER restored token=0x${restored?.token.toRadixString(16)} '
        'same=${'${restored?.entries}' == '${before.entries}'}',
      );
      log('NAMES restored ${await tailNames()}');

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
