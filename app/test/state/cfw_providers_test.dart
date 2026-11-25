import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/test_assets.dart';

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

/// Records the order of the reads the connect sequence and the heartbeat make.
class _SpyService extends DeviceService {
  _SpyService({this.dsp, this.dspThrows = false})
    : super(_ReplyingTransport(const {}));

  final int? dsp;
  final bool dspThrows;
  final calls = <String>[];
  Completer<void>? dspGate;

  @override
  Future<String?> requestPresetNames({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    calls.add('names');

    return null;
  }

  @override
  Future<String?> requestUserNames(
    String requestHex, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestCfwSettings({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    calls.add('cfw');

    return null;
  }

  @override
  Future<int?> requestDspLoad({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    calls.add('dsp');
    await dspGate?.future;
    if (dspThrows) throw StateError('send failed');

    return dsp;
  }
}

ProviderContainer _spyContainer(_SpyService spy, {bool isLoading = false}) =>
    ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(spy),
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
        presetLoadingProvider.overrideWith((_) => isLoading),
      ],
    );

final _cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

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

  testWidgets('the status poll reads the DSP only on a CFW pedal', (
    tester,
  ) async {
    final service = DeviceService(
      _ReplyingTransport({CfwSettingWriter.readDsp().toLowerCase(): _dspReply}),
    )..startListening();
    final c = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(service),
        connectionStateProvider.overrideWith((_) => true),
      ],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

    final ref = await _ref(tester, c);

    await tester.runAsync(() => pollCfwStatus(ref));
    expect(c.read(dspLoadProvider), isNull); // stock: no DSP read

    c.read(cfwInfoProvider.notifier).state = decodeCfwSettingsFrame(
      cfwSettingsOriginal,
    );
    await tester.runAsync(() => pollCfwStatus(ref));
    expect(c.read(dspLoadProvider), 57);
  });

  testWidgets('after connecting, the CFW read waits for the preset names', (
    tester,
  ) async {
    final spy = _SpyService();
    final c = _spyContainer(spy);

    addTearDown(c.dispose);

    final ref = await _ref(tester, c);

    await tester.runAsync(() => refreshNamesThenCfw(ref));

    expect(spy.calls.first, 'names');
    expect(spy.calls.last, 'cfw');
  });

  group('the DSP status poll', () {
    testWidgets('stays quiet while a load or upload holds the pedal', (
      tester,
    ) async {
      final spy = _SpyService(dsp: 57);
      final c = _spyContainer(spy, isLoading: true);

      addTearDown(c.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;

      final ref = await _ref(tester, c);

      await tester.runAsync(() => pollCfwStatus(ref));

      expect(spy.calls, isEmpty);
    });

    testWidgets('a missed read clears the chip instead of freezing it', (
      tester,
    ) async {
      final spy = _SpyService();
      final c = _spyContainer(spy);

      addTearDown(c.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;
      c.read(dspLoadProvider.notifier).state = 57;

      final ref = await _ref(tester, c);

      await tester.runAsync(() => pollCfwStatus(ref));

      expect(c.read(dspLoadProvider), isNull);
    });

    testWidgets('a send error is swallowed', (tester) async {
      final spy = _SpyService(dspThrows: true);
      final c = _spyContainer(spy);

      addTearDown(c.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;

      final ref = await _ref(tester, c);

      await tester.runAsync(() => pollCfwStatus(ref));

      expect(c.read(dspLoadProvider), isNull);
    });

    testWidgets('a stalled read does not stack another one', (tester) async {
      final spy = _SpyService(dsp: 57)..dspGate = Completer<void>();
      final c = _spyContainer(spy);

      addTearDown(c.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;

      final ref = await _ref(tester, c);

      await tester.runAsync(() async {
        final first = pollCfwStatus(ref);
        final second = pollCfwStatus(ref);

        spy.dspGate!.complete();
        await Future.wait([first, second]);
      });

      expect(spy.calls.where((c) => c == 'dsp'), hasLength(1));
    });
  });

  testWidgets('a new connection starts with no CFW state', (tester) async {
    final c = ProviderContainer();

    addTearDown(c.dispose);
    c.read(cfwInfoProvider.notifier).state = _cfw;
    c.read(dspLoadProvider.notifier).state = 57;

    final ref = await _ref(tester, c);

    clearCfwState(ref);

    expect(c.read(cfwInfoProvider), isNull);
    expect(c.read(dspLoadProvider), isNull);
  });
}
