// Live CFW gate for the battery reading — requires a Pocket Master on the
// community custom firmware, advertising over BLE and free. Read-only: reads
// `12 2D` three times and writes each to <app tmp>/cfw_live6.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('battery reading on the real pedal', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_live6.txt');

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

      final cfw = await service.requestCfwSettings(
        timeout: const Duration(seconds: 4),
      );

      log('CFW ${cfw == null ? 'no reply' : 'ok'}');

      for (var i = 0; i < 3; i++) {
        final s = await service.requestBattery(
          timeout: const Duration(seconds: 4),
        );

        log(
          s == null
              ? 'BATTERY null'
              : 'BATTERY mv=${s.millivolts} charge=${s.charge.name} '
                    'bars=${s.bars} flags=0x${s.flags.toRadixString(16)} '
                    'empty=${s.emptyMillivolts} label="${s.label}"',
        );
      }

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
