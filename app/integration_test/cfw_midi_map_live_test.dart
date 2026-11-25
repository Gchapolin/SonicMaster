// Live CFW gate for the custom MIDI map — requires a Pocket Master on the
// community custom firmware, advertising over BLE and free, with an EMPTY
// custom map (else it only reads). Writes 10 rows, reads them back, writes the
// empty map again; each step goes to <app tmp>/cfw_live5.txt. The MIDI map
// setting (Stock / Custom ...) is not touched.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/model/midi_map.dart';
import 'package:sonicmaster/protocol/cfw_midi_map_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom MIDI map round-trip on the real pedal', (tester) async {
    final out = File('${Directory.systemTemp.path}/cfw_live5.txt');

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
      const wait = Duration(seconds: 4);

      Future<({int count, int options, int crc})?> info() async {
        final hex = await service.requestMidiMapInfo(timeout: wait);

        return hex == null ? null : decodeMidiMapInfo(hex);
      }

      Future<List<MidiMapEntry>> rows(int count) async {
        final out = <MidiMapEntry>[];

        while (out.length < count) {
          final hex = await service.requestMidiMapPage(
            out.length,
            timeout: wait,
          );
          final page = hex == null ? null : decodeMidiMapPage(hex);

          if (page == null || page.entries.isEmpty) break;
          out.addAll(page.entries);
        }

        return out;
      }

      Future<bool> write(int options, List<MidiMapEntry> entries) async {
        for (final f in buildMidiMapFrames(
          options: options,
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

      Future<String> settings() async {
        final hex = await service.requestCfwSettings(timeout: wait);
        final cfw = hex == null ? null : decodeCfwSettingsFrame(hex);

        return 'map=${cfw?.midiMap} options(0x17)=${cfw?.customMapOptions}';
      }

      log('SETTINGS ${await settings()}');

      // Housekeeping from the capture session: the empty map was left with
      // header options 1; the pedal's original was 0.
      final first = await info();

      if (first != null && first.count == 0 && first.options != 0) {
        log('RESET empty map to options 0 acked=${await write(0, const [])}');
        await Future<void>.delayed(const Duration(milliseconds: 600));
        log('SETTINGS after reset ${await settings()}');
      }

      final before = await info();

      log(
        'INFO before count=${before?.count} options=${before?.options} '
        'crc=0x${before?.crc.toRadixString(16)}',
      );
      if (before == null) return;
      if (before.count != 0) {
        log(
          'SKIPPED: the custom map is not empty: ${await rows(before.count)}',
        );

        return;
      }

      final probe = [
        for (var i = 0; i < 9; i++)
          MidiMapEntry(from: 20 + i, to: 20 + i, function: 12, which: i),
        const MidiMapEntry(
          trigger: MidiMapEntry.pc,
          from: 101,
          to: 102,
          function: 2,
        ),
      ];

      log('WRITE 10 rows acked=${await write(before.options, probe)}');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final after = await info();
      final back = await rows(after?.count ?? 0);

      log(
        'INFO after count=${after?.count} crc=0x${after?.crc.toRadixString(16)} '
        'expected=0x${midiMapCrc(before.options, probe).toRadixString(16)}',
      );
      log('ROWS match=${'$back' == '$probe'}');
      log('ROW 9 ${back.isEmpty ? null : back.last.describe()}');

      log('WRITE empty acked=${await write(before.options, const [])}');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final restored = await info();

      log(
        'INFO restored count=${restored?.count} options=${restored?.options} '
        'crc=0x${restored?.crc.toRadixString(16)} '
        'same=${restored?.crc == before.crc}',
      );

      log('SETTINGS end ${await settings()}');
      await service.disconnect();
      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
