import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/midi_map.dart';
import 'package:sonicmaster/protocol/cfw_midi_map_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/midi_map_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';
import '../support/sonic_host.dart';
import '../support/view_helpers.dart';

const _bank = MidiMapEntry(
  trigger: MidiMapEntry.pc,
  from: 101,
  to: 102,
  function: 2,
);
const _freeze = MidiMapEntry(from: 80, to: 80, function: 17, switchMode: 1);

/// A pedal holding [stored] rows (null: it never answers the map read).
class _MapPedal extends DeviceService {
  _MapPedal(this.stored) : super(SilentTransport());

  final List<MidiMapEntry>? stored;
  final acks = 999;
  final sent = <String>[];
  void Function()? onWrite;

  @override
  Future<String?> requestCfwSettings({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestMidiMapInfo({
    Duration timeout = const Duration(seconds: 1),
  }) async => stored == null
      ? null
      : buildSysexWriteFrame([
          0x12, 0x39, 0x00, 0x01, 0x01, 0x81, stored!.length, 0x40, 0x00, //
          0x03, 0, 0, 0, 0, 0, 0x01,
        ]);

  @override
  Future<String?> requestMidiMapPage(
    int first, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final part = stored!.skip(first).take(8).toList();

    return buildSysexWriteFrame([
      0x12,
      0x39,
      0x01,
      first,
      part.length,
      for (final e in part) ...e.toBytes(),
    ]);
  }

  @override
  Future<bool> sendFramesAcked(
    List<String> frames, {
    Duration ackTimeout = const Duration(milliseconds: 1200),
    int ackRetries = 4,
  }) async {
    onWrite?.call();
    for (final f in frames) {
      sent.add(f);
      if (sent.length > acks) return false;
    }

    return true;
  }
}

void main() {
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<_MapPedal> open(
    WidgetTester tester,
    List<MidiMapEntry>? stored, {
    Size size = const Size(1280, 800),
  }) async {
    final pedal = _MapPedal(stored);
    final context = await pumpSonicHost(
      tester,
      size: size,
      overrides: [
        deviceServiceProvider.overrideWithValue(pedal),
        cfwInfoProvider.overrideWith((_) => cfw),
      ],
    );

    unawaited(
      showSonicDialog<void>(
        context: context,
        builder: (_) => const MidiMapDialog(),
      ),
    );
    await tester.pumpAndSettle();

    return pedal;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
    await tester.tap(find.text(text).last);
    await tester.pump();
  }

  testWidgets('lists the rows the pedal holds', (tester) async {
    await open(tester, const [_bank, _freeze]);

    expect(find.text('2 / 64 rows'), findsOneWidget);
    expect(find.text('PC 101–102 → Bank −, Bank +'), findsOneWidget);
    expect(find.text('CC 80 → Freeze · toggle'), findsOneWidget);
  });

  testWidgets('a new row is sent only on Save to pedal', (tester) async {
    final pedal = await open(tester, const []);

    await tapText(tester, 'Add row');

    expect(find.text('CC 0 → Tap tempo'), findsOneWidget);
    expect(find.text('1 / 64 rows · Not saved yet'), findsOneWidget);
    expect(pedal.sent, isEmpty);

    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(options: 0, entries: const [MidiMapEntry()]),
    );
    expect(find.text('1 / 64 rows · Saved to the pedal'), findsOneWidget);
  });

  testWidgets('the form builds the row: trigger and function', (tester) async {
    final pedal = await open(tester, const []);

    await tapText(tester, 'CC');
    await tapText(tester, 'PC');
    await tapText(tester, 'Tap tempo');
    await tapText(tester, 'Scene');
    await tapText(tester, 'Add row');
    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(
        options: 0,
        entries: const [MidiMapEntry(trigger: MidiMapEntry.pc, function: 14)],
      ),
    );
  });

  testWidgets('deleting a row and saving writes the rest', (tester) async {
    final pedal = await open(tester, const [_bank, _freeze]);

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pump();
    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(options: 0, entries: const [_freeze]),
    );
  });

  testWidgets('editing a row replaces it in place', (tester) async {
    final pedal = await open(tester, const [_bank, _freeze]);

    await tester.tap(find.byIcon(Icons.edit).last);
    await tester.pump();
    await tapText(tester, 'Toggle');
    await tapText(tester, 'Momentary');
    await tapText(tester, 'Update row');
    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(
        options: 0,
        entries: [_bank, _freeze.copyWith(switchMode: 2)],
      ),
    );
  });

  testWidgets('an unread map cannot be saved over the pedal\'s', (
    tester,
  ) async {
    final pedal = await open(tester, null);

    expect(find.text('The pedal did not send its map'), findsOneWidget);
    expect(find.text('Add row'), findsNothing);

    await tapText(tester, 'Save to pedal');

    expect(pedal.sent, isEmpty);
    expect(find.text('Read again'), findsOneWidget);
  });

  testWidgets('a full map takes no more rows', (tester) async {
    await open(tester, [
      for (var i = 0; i < 64; i++) MidiMapEntry(from: i, to: i),
    ]);

    await tapText(tester, 'Add row');

    expect(find.text('64 / 64 rows'), findsOneWidget);
  });

  testWidgets('phone: the editor fits', (tester) async {
    await open(tester, const [_bank, _freeze], size: const Size(852, 393));

    expectNoOverflow(tester);
  });

  testWidgets('a PC row carries no value condition', (tester) async {
    final pedal = await open(tester, const []);

    await tapText(tester, 'any');
    await tapText(tester, '≥ 64');
    await tapText(tester, 'CC');
    await tapText(tester, 'PC');
    await tapText(tester, 'Add row');
    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(
        options: 0,
        entries: const [MidiMapEntry(trigger: MidiMapEntry.pc)],
      ),
    );
  });

  testWidgets('a function without a switch drops the switch mode', (
    tester,
  ) async {
    final pedal = await open(tester, const [_freeze]);

    await tester.tap(find.byIcon(Icons.edit).last);
    await tester.pump();
    await tapText(tester, 'Freeze');
    await tapText(tester, 'Tap tempo');
    await tapText(tester, 'Update row');
    await tapText(tester, 'Save to pedal');
    await tester.pump();

    expect(
      pedal.sent,
      buildMidiMapFrames(
        options: 0,
        entries: const [MidiMapEntry(from: 80, to: 80)],
      ),
    );
  });
}
