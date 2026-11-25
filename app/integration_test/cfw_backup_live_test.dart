// Live CFW gate for the whole-pedal backup — requires a Pocket Master on the
// community custom firmware, advertising over BLE and free. Read-only: reads
// the pedal the way "Back up now" does, checks the file passes the CFW app's
// checks and writes it and a log to <app tmp>/cfw_backup_live.*. Nothing is
// written to the pedal (there is deliberately no live restore gate).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/protocol/cfw_backup.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_backup_io.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('whole-pedal backup on the real pedal (read-only)', (
    tester,
  ) async {
    final out = File('${Directory.systemTemp.path}/cfw_backup_live.txt');

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

      final hex = await service.requestCfwSettings(
        timeout: const Duration(seconds: 4),
      );
      final info = hex == null ? null : decodeCfwSettingsFrame(hex);

      log(
        'CFW ${info == null ? 'none' : '${info.version} caps 0x${info.capabilities.toRadixString(16)} caps2 0x${info.extraCapabilities.toRadixString(16)}'}',
      );
      if (info == null) return;

      final watch = Stopwatch()..start();
      final backup = await readPedalBackup(
        service,
        info,
        app: 'SonicMaster live gate',
        onProgress: (step, done, total) {
          if (done % 10 == 0) log('  $done/$total $step');
        },
      );
      final text = encodeCfwBackup(backup);

      log('READ in ${watch.elapsed.inSeconds} s, ${text.length} chars');
      log('SECTIONS ${backup.sections}');
      log(
        'SCENES on ${backup.presets.where((p) => p.scenes != null).map((p) => p.label).join(' ')}',
      );
      log(
        'EXP on ${backup.presets.where((p) => p.midiPedals != null).map((p) => p.label).join(' ')}',
      );
      log('CHECK ${parseCfwBackup(text).$2}');
      File(
        '${Directory.systemTemp.path}/cfw_backup_live.smbackup.json',
      ).writeAsStringSync(text);

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
