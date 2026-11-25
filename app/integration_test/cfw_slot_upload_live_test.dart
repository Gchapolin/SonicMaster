// Live CFW gate for files in slots 6-10 — requires a Pocket Master on the
// community custom firmware, advertising over BLE and free, with User IR 10
// empty. Loads a synthetic IR into User IR 10, renames it, clears it; writes
// each step to <app tmp>/cfw_live4.txt.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/protocol/cfw_slot_names_codec.dart';
import 'package:sonicmaster/protocol/ir_upload_frame.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IR file in slot 10 on the real pedal', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_live4.txt');

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

      Future<String?> name10() async {
        final hex = await service.requestCfwSlotNames(
          cfwIrNamesRegister,
          timeout: const Duration(seconds: 4),
        );

        return hex == null
            ? 'no answer'
            : decodeCfwSlotNames(hex, cfwIrNamesRegister)?[9];
      }

      const slot = 9;
      final before = await name10();

      log('IR10 before "$before"');
      if (before != 'User IR 10') {
        log('SKIPPED: User IR 10 is not empty');

        return;
      }

      final samples = [
        for (var i = 0; i < IrUploadFrame.deviceTaps; i++)
          (IrUploadFrame.fullScale *
                  0.8 *
                  math.exp(-i / 40) *
                  math.cos(i * 0.9))
              .round(),
      ];
      final upload = await service.uploadIr(
        IrUploadFrame.buildChunks(
          IrUploadFrame.buildBlob(
            slot: slot,
            name: 'LiveTest',
            samples: samples,
          ),
        ),
      );

      log('UPLOAD $upload -> "${await name10()}"');

      final rename = await service.uploadIr(
        IrUploadFrame.buildChunks(
          IrUploadFrame.buildRenameBlob(slot: slot, name: 'Renamed'),
        ),
      );

      log('RENAME $rename -> "${await name10()}"');

      final clear = await service.uploadIr(
        IrUploadFrame.buildChunks(IrUploadFrame.buildClearBlob(slot: slot)),
      );

      log('CLEAR $clear -> "${await name10()}"');

      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
