import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';

import '../fixtures/cfw_dumps.dart';

/// A frame as the transports deliver it: the `8080` BLE header stripped, so
/// it starts at `F0` (see classifyInbound).
Uint8List _bytes(String frameHex) {
  final hex = frameHex.toLowerCase().replaceFirst(RegExp('^8080'), '');

  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// A pedal that answers chosen read frames with chosen reply frames.
class _ReplyingTransport implements Transport {
  _ReplyingTransport(this.replies);

  final Map<String, String> replies;
  final _packets = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> rawPackets() => _packets.stream;

  @override
  Future<void> connect({String? target}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<bool>? connectionEvents() => null;

  @override
  Future<void> sendFrame(String frameHex) async {
    final reply = replies[frameHex.toLowerCase()];

    if (reply != null) {
      scheduleMicrotask(() => _packets.add(_bytes(reply)));
    }
  }
}

/// The DSP status reply, built with the captured payload
/// `12 2B 01 03 39 00 …` (57 %).
final _dspReply = buildSysexWriteFrame([
  0x12, 0x2B, 0x01, 0x03, 0x39, 0x00, 0x10, 0x0E, 0x00, 0x00, //
]);

Future<WidgetRef> _ref(WidgetTester tester, ProviderContainer c) async {
  late WidgetRef captured;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: Consumer(
        builder: (_, ref, _) {
          captured = ref;

          return const SizedBox();
        },
      ),
    ),
  );

  return captured;
}

void main() {
  testWidgets('a CFW pedal fills cfwInfoProvider with its version', (
    tester,
  ) async {
    final service = DeviceService(
      _ReplyingTransport({
        CfwSettingWriter.readSettings().toLowerCase(): cfwSettingsOriginal,
      }),
    )..startListening();
    final c = ProviderContainer(
      overrides: [deviceServiceProvider.overrideWithValue(service)],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

    final ref = await _ref(tester, c);

    await tester.runAsync(() => refreshCfwInfo(ref));

    expect(c.read(cfwInfoProvider)?.version, 'CFW1.0.2');
    expect(c.read(cfwInfoProvider)?.theme, 3);
  });

  testWidgets('a stock pedal (no reply) leaves cfwInfoProvider null', (
    tester,
  ) async {
    final service = DeviceService(_ReplyingTransport({}))..startListening();
    final c = ProviderContainer(
      overrides: [deviceServiceProvider.overrideWithValue(service)],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

    final ref = await _ref(tester, c);

    await tester.runAsync(
      () => refreshCfwInfo(ref, timeout: const Duration(milliseconds: 50)),
    );

    expect(c.read(cfwInfoProvider), isNull);
  });

  testWidgets('the DSP read fills dspLoadProvider with the percent', (
    tester,
  ) async {
    final service = DeviceService(
      _ReplyingTransport({CfwSettingWriter.readDsp().toLowerCase(): _dspReply}),
    )..startListening();
    final c = ProviderContainer(
      overrides: [deviceServiceProvider.overrideWithValue(service)],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

    final ref = await _ref(tester, c);

    await tester.runAsync(() => refreshDspLoad(ref));

    expect(c.read(dspLoadProvider), 57);
  });
}
