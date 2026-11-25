import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_info.dart';
import 'package:sonicmaster/model/midi_map.dart';
import 'package:sonicmaster/protocol/cfw_midi_map_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';

final _rows = [
  for (var i = 0; i < 11; i++)
    MidiMapEntry(trigger: MidiMapEntry.cc, from: i, to: i, function: 5),
];

/// A pedal holding [stored] rows; acks the first [acks] frames it is sent.
class _MapPedal extends DeviceService {
  _MapPedal({this.stored, this.acks = 999}) : super(SilentTransport());

  final List<MidiMapEntry>? stored;
  final int acks;
  final sent = <String>[];
  final pages = <int>[];

  @override
  Future<String?> requestMidiMapInfo({
    Duration timeout = const Duration(seconds: 1),
  }) async => stored == null
      ? null
      : buildSysexWriteFrame([
          0x12, 0x39, 0x00, 0x01, 0x01, 0x81, stored!.length, 0x40, 0x00, //
          0x03, 0, 0, 0, 0x43, 0x0e, 0x01,
        ]);

  @override
  Future<String?> requestMidiMapPage(
    int first, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    pages.add(first);

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
  Future<bool> sendAndAwaitAck(
    String frameHex, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    sent.add(frameHex);

    return sent.length <= acks;
  }
}

Future<(WidgetRef, ProviderContainer)> _host(
  WidgetTester tester,
  _MapPedal pedal, {
  CfwInfo? cfw,
  bool isCfw = true,
}) async {
  final c = ProviderContainer(
    overrides: [deviceServiceProvider.overrideWithValue(pedal)],
  );

  addTearDown(c.dispose);
  if (isCfw) {
    c.read(cfwInfoProvider.notifier).state =
        cfw ?? decodeCfwSettingsFrame(cfwSettingsOriginal);
  }

  late WidgetRef ref;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: Consumer(
        builder: (_, r, _) {
          ref = r;

          return const SizedBox();
        },
      ),
    ),
  );

  return (ref, c);
}

void main() {
  testWidgets('reading the map pages through all its rows', (tester) async {
    final pedal = _MapPedal(stored: _rows);
    final (ref, c) = await _host(tester, pedal);

    await tester.runAsync(() => refreshMidiMap(ref));

    expect(pedal.pages, [0, 8]);
    expect(c.read(midiMapProvider), _rows);
  });

  testWidgets('an empty map reads as no rows, a silent pedal as unknown', (
    tester,
  ) async {
    final (ref, c) = await _host(tester, _MapPedal(stored: const []));

    await tester.runAsync(() => refreshMidiMap(ref));
    expect(c.read(midiMapProvider), isEmpty);

    final (silentRef, silent) = await _host(tester, _MapPedal());

    await tester.runAsync(() => refreshMidiMap(silentRef));
    expect(silent.read(midiMapProvider), isNull);
  });

  testWidgets('saving sends the map with the pedal\'s custom-map options', (
    tester,
  ) async {
    final pedal = _MapPedal(stored: const []);
    final cfw = decodeCfwSettingsFrame(
      cfwSettingsOriginal,
    )!.copyWithSetting(CfwInfo.customMapOptionsKey, 3);
    final (ref, c) = await _host(tester, pedal, cfw: cfw);

    expect(await tester.runAsync(() => saveMidiMap(ref, _rows)), isTrue);
    expect(pedal.sent, buildMidiMapFrames(options: 3, entries: _rows));
    expect(c.read(midiMapProvider), _rows);
  });

  testWidgets('a missing ack stops the save and keeps what was read', (
    tester,
  ) async {
    final pedal = _MapPedal(stored: const [], acks: 2);
    final (ref, c) = await _host(tester, pedal);

    await tester.runAsync(() => refreshMidiMap(ref));

    expect(await tester.runAsync(() => saveMidiMap(ref, _rows)), isFalse);
    expect(pedal.sent, hasLength(3));
    expect(c.read(midiMapProvider), isEmpty);
  });

  testWidgets('more than 64 rows or stock firmware write nothing', (
    tester,
  ) async {
    final pedal = _MapPedal(stored: const []);
    final (ref, _) = await _host(tester, pedal);
    final tooMany = [for (var i = 0; i < 65; i++) const MidiMapEntry()];

    expect(await tester.runAsync(() => saveMidiMap(ref, tooMany)), isFalse);

    final stock = _MapPedal(stored: const []);
    final (stockRef, sc) = await _host(tester, stock, isCfw: false);

    expect(await tester.runAsync(() => saveMidiMap(stockRef, _rows)), isFalse);
    await tester.runAsync(() => refreshMidiMap(stockRef));

    expect(pedal.sent, isEmpty);
    expect(stock.sent, isEmpty);
    expect(stock.pages, isEmpty);
    expect(sc.read(midiMapProvider), isNull);
  });

  testWidgets('a new connection forgets the map', (tester) async {
    final (ref, c) = await _host(tester, _MapPedal(stored: _rows));

    await tester.runAsync(() => refreshMidiMap(ref));
    clearCfwState(ref);

    expect(c.read(midiMapProvider), isNull);
  });
}
