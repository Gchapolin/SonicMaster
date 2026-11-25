import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/model/battery_status.dart';
import 'package:sonicmaster/model/cfw_firmware_variants.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/cfw_slot_names_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
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

/// A silent pedal that records what it is sent.
class _RecordingTransport extends _ReplyingTransport {
  _RecordingTransport(this.sent) : super(const {});

  final List<String> sent;

  @override
  Future<void> sendFrame(String frameHex) async => sent.add(frameHex);
}

/// The DSP status reply, built with the captured payload
/// `12 2B 01 03 39 00 …` (57 %).
final _dspReply = buildSysexWriteFrame([
  0x12, 0x2B, 0x01, 0x03, 0x39, 0x00, 0x10, 0x0E, 0x00, 0x00, //
]);

/// Records the order of the reads the connect sequence and the heartbeat make.
class _SpyService extends DeviceService {
  _SpyService({this.dsp, this.dspThrows = false, this.battery})
    : super(_ReplyingTransport(const {}));

  final int? dsp;
  final bool dspThrows;
  final BatteryStatus? battery;
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

  @override
  Future<BatteryStatus?> requestBattery({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    calls.add('battery');

    return battery;
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

/// A multi-packet reply as the reassembler hands it over: a synthetic
/// `<crc> 01 00 00` header, then the nibble-expanded payload.
String _reassembled(List<int> payload) => [
  '8080f0', '0000', '0001', '0000', '0000', //
  for (final b in payload)
    '0${(b >> 4).toRadixString(16)}0${(b & 0xF).toRadixString(16)}',
  'f7',
].join();

/// A captured-shape `12 <register>` names reply: `01 0a <kind>` + 10 x 32.
String _slotNames(int register, List<String> names) => _reassembled([
  0x12,
  register,
  0x01,
  names.length,
  register == 0x28 ? 0 : 1,
  for (final n in names) ...[...n.codeUnits, ...List.filled(32 - n.length, 0)],
]);

void main() {
  group('the CFW slot names', () {
    final replies = {
      readCfwSlotNamesFrame(0x28).toLowerCase(): _slotNames(0x28, [
        for (var i = 1; i <= 10; i++) i == 7 ? 'Mesa 412 V30' : 'User IR $i',
      ]),
      readCfwSlotNamesFrame(0x29).toLowerCase(): _slotNames(0x29, [
        'Randall SATAN 50 Mic Center',
        for (var i = 2; i <= 10; i++) i == 10 ? 'Plexi' : 'Empty',
      ]),
    };

    testWidgets('fill the ten IR and ten profile names on a CFW pedal', (
      tester,
    ) async {
      // Two reads in a row: the inbound pipeline must live in the real-async
      // zone, or its second frame waits for a pump that never comes.
      final service = (await tester.runAsync(
        () async =>
            DeviceService(_ReplyingTransport(replies))..startListening(),
      ))!;
      final c = ProviderContainer(
        overrides: [deviceServiceProvider.overrideWithValue(service)],
      );

      addTearDown(c.dispose);
      addTearDown(service.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;
      c.read(userNamesProvider.notifier).state = {902: 'User Profile 2'};

      final ref = await _ref(tester, c);

      await tester.runAsync(() => refreshCfwSlotNames(ref));

      final names = c.read(userNamesProvider);

      expect(names[416], 'User IR 1');
      expect(names[423], 'Mesa 412 V30'); // slot 7
      expect(names[426], 'User IR 10');
      expect(names.containsKey(421), isFalse); // a factory cab, not a slot
      expect(names[901], 'Randall SATAN 50 Mic Center');
      expect(names[910], 'Plexi');
      // An empty slot keeps what was there (or the library name).
      expect(names[902], 'User Profile 2');
      expect(names.containsKey(906), isFalse);
    });

    testWidgets('survive the stock IR name refresh after an upload', (
      tester,
    ) async {
      final service = (await tester.runAsync(
        () async =>
            DeviceService(_ReplyingTransport(replies))..startListening(),
      ))!;
      final c = ProviderContainer(
        overrides: [
          deviceServiceProvider.overrideWithValue(service),
          dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
        ],
      );

      addTearDown(c.dispose);
      addTearDown(service.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;

      final ref = await _ref(tester, c);

      await tester.runAsync(() => refreshIrNames(ref));
      expect(c.read(userNamesProvider)[423], 'Mesa 412 V30');

      await tester.runAsync(() => refreshCloneNames(ref));
      expect(c.read(userNamesProvider)[901], 'Randall SATAN 50 Mic Center');
    });

    testWidgets('are not read on stock firmware', (tester) async {
      final sent = <String>[];
      final service = DeviceService(_RecordingTransport(sent))
        ..startListening();
      final c = ProviderContainer(
        overrides: [deviceServiceProvider.overrideWithValue(service)],
      );

      addTearDown(c.dispose);
      addTearDown(service.dispose);

      final ref = await _ref(tester, c);

      await tester.runAsync(() => refreshCfwSlotNames(ref));

      expect(sent, isEmpty);
      expect(c.read(userNamesProvider), isEmpty);
    });
  });

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

  testWidgets('the CFW read fits Swell Delay to the pedal; a new connection '
      'puts it back', (tester) async {
    final service = DeviceService(
      _ReplyingTransport({
        CfwSettingWriter.readSettings().toLowerCase(): cfwSettingsOriginal,
      }),
    )..startListening();
    final c = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(service),
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
      ],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

    final ref = await _ref(tester, c);
    final data = c.read(dataAssetsProvider).requireValue;
    String slot6() => data.effects
        .byId(swellDelayId)!
        .params
        .singleWhere((p) => p.algId == 6)
        .name;

    expect(slot6(), 'Duck');

    // The captured CFW 1.0.2 carries capability bit 31 (sbModels097).
    await tester.runAsync(() => refreshCfwInfo(ref));
    expect(slot6(), 'Sens');

    clearCfwState(ref);
    expect(slot6(), 'Duck');
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

    testWidgets('reads the battery after the DSP load', (tester) async {
      const status = BatteryStatus(
        flags: 1,
        millivolts: 3880,
        charge: BatteryCharge.charging,
        bars: 2,
        emptyMillivolts: 3540,
      );
      final spy = _SpyService(dsp: 57, battery: status);
      final c = _spyContainer(spy);

      addTearDown(c.dispose);
      c.read(cfwInfoProvider.notifier).state = _cfw;

      final ref = await _ref(tester, c);

      await tester.runAsync(() => pollCfwStatus(ref));

      expect(spy.calls, ['dsp', 'battery']);
      expect(c.read(batteryProvider), same(status));
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
