import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/protocol/cfw_preset_order_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';

final _identity = [for (var i = 0; i < 50; i++) i];

/// A pedal with an order table; acks the first [acks] packets it is sent.
class _OrderPedal extends DeviceService {
  _OrderPedal({this.table, this.acks = 99}) : super(SilentTransport());

  final List<int>? table;
  final int acks;
  final sent = <String>[];
  var namesReads = 0;

  @override
  Future<String?> requestPresetOrder({
    Duration timeout = const Duration(seconds: 1),
  }) async => table == null
      ? null
      : buildSysexWriteFrame([0x12, 0x37, 1, 2, 0x83, ...table!]);

  @override
  Future<bool> sendAndAwaitAck(
    String frameHex, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    sent.add(frameHex);

    return sent.length <= acks;
  }

  @override
  Future<String?> requestPresetNames({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    namesReads++;

    return null;
  }

  @override
  Future<String?> requestUserNames(
    String requestHex, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestCfwSlotNames(
    int register, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

Future<(WidgetRef, ProviderContainer)> _host(
  WidgetTester tester,
  _OrderPedal pedal, {
  bool isCfw = true,
}) async {
  final c = ProviderContainer(
    overrides: [deviceServiceProvider.overrideWithValue(pedal)],
  );

  addTearDown(c.dispose);
  if (isCfw) {
    c.read(cfwInfoProvider.notifier).state = decodeCfwSettingsFrame(
      cfwSettingsOriginal,
    );
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
  testWidgets('moving a preset writes the new table with the read token', (
    tester,
  ) async {
    final pedal = _OrderPedal(table: _identity);
    final (ref, c) = await _host(tester, pedal);

    c.read(presetNamesProvider.notifier).state = {
      const PresetRef(.user, 17): 'Fuzz Boy',
      const PresetRef(.user, 18): 'HB Drive',
      const PresetRef(.user, 19): 'Dead Metal',
    };

    final ok = await tester.runAsync(() => moveUserPreset(ref, 18, 17));

    expect(ok, isTrue);
    expect(
      pedal.sent,
      buildPresetOrderFrames(
        token: 0x83,
        entries: movePreset(_identity, from: 17, to: 16),
      ),
    );
    // The names follow at once, without waiting for the pedal's dump.
    expect(c.read(presetNamesProvider)[const PresetRef(.user, 17)], 'HB Drive');
    expect(c.read(presetNamesProvider)[const PresetRef(.user, 18)], 'Fuzz Boy');
    expect(
      c.read(presetNamesProvider)[const PresetRef(.user, 19)],
      'Dead Metal',
    );
  });

  testWidgets('the loaded preset keeps its identity at its new position', (
    tester,
  ) async {
    final (ref, c) = await _host(tester, _OrderPedal(table: _identity));

    c.read(currentPresetProvider.notifier).state = const PresetRef(.user, 18);
    await tester.runAsync(() => moveUserPreset(ref, 18, 3));
    expect(c.read(currentPresetProvider), const PresetRef(.user, 3));

    // A preset in between shifts by one.
    c.read(currentPresetProvider.notifier).state = const PresetRef(.user, 5);
    await tester.runAsync(() => moveUserPreset(ref, 2, 9));
    expect(c.read(currentPresetProvider), const PresetRef(.user, 4));

    // A factory preset is untouched.
    c.read(currentPresetProvider.notifier).state = const PresetRef(.factory, 5);
    await tester.runAsync(() => moveUserPreset(ref, 2, 9));
    expect(c.read(currentPresetProvider), const PresetRef(.factory, 5));
  });

  testWidgets('a missing ack stops the write and reports failure', (
    tester,
  ) async {
    final pedal = _OrderPedal(table: _identity, acks: 1);
    final (ref, c) = await _host(tester, pedal);

    c.read(presetNamesProvider.notifier).state = {
      const PresetRef(.user, 17): 'Fuzz Boy',
    };

    expect(await tester.runAsync(() => moveUserPreset(ref, 18, 17)), isFalse);
    expect(pedal.sent, hasLength(2)); // stopped after the unacked packet
    expect(c.read(presetNamesProvider)[const PresetRef(.user, 17)], 'Fuzz Boy');
  });

  testWidgets('nothing is written without a table, on stock or for a no-op', (
    tester,
  ) async {
    final silent = _OrderPedal();
    final (ref, _) = await _host(tester, silent);

    expect(await tester.runAsync(() => moveUserPreset(ref, 18, 17)), isFalse);
    expect(silent.sent, isEmpty);

    final stock = _OrderPedal(table: _identity);
    final (stockRef, _) = await _host(tester, stock, isCfw: false);

    expect(
      await tester.runAsync(() => moveUserPreset(stockRef, 18, 17)),
      isFalse,
    );
    expect(stock.sent, isEmpty);

    final same = _OrderPedal(table: _identity);
    final (sameRef, _) = await _host(tester, same);

    expect(await tester.runAsync(() => moveUserPreset(sameRef, 7, 7)), isFalse);
    expect(await tester.runAsync(() => moveUserPreset(sameRef, 0, 7)), isFalse);
    expect(
      await tester.runAsync(() => moveUserPreset(sameRef, 7, 51)),
      isFalse,
    );
    expect(same.sent, isEmpty);
  });
}
