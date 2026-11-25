import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_exp_codec.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/protocol/inbound_message.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/hardware_sync.dart';
import 'package:sonicmaster/state/preset_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

/// A CFW pedal whose reads answer from fixed replies, without a transport.
class _FakeCfw extends DeviceService {
  _FakeCfw() : super(SilentTransport());

  final sentFrames = <String>[];

  static final recordsReply = buildSysexWriteFrame([
    0x12, 0x33, 0x53, 0x43, 0x01, 0x01, 0x14, 0x00, 0xc3, 0xc2, //
    0x03, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00, 0x07, 0x00, 0x00, 0x04, 0x42,
  ]);

  @override
  Future<void> sendFrame(String frameHex) async => sentFrames.add(frameHex);

  @override
  Future<String?> requestPresetNames({
    Duration timeout = const Duration(seconds: 2),
  }) async => null;

  @override
  Future<String?> requestUserNames(
    String requestHex, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestCfwSettings({
    Duration timeout = const Duration(seconds: 1),
  }) async => cfwSettingsOriginal;

  @override
  Future<String?> requestSceneRecords({
    Duration timeout = const Duration(seconds: 1),
  }) async => recordsReply;

  @override
  Future<String?> requestCurrentScene({
    Duration timeout = const Duration(seconds: 1),
  }) async => buildSysexWriteFrame([0x12, 0x32, 0x01, 0x01, 0, 0, 0, 0]);

  @override
  Future<String?> requestCfwSlotNames(
    int register, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestExpAssigns({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestStateDump({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

Future<(WidgetRef, ProviderContainer, _FakeCfw)> _withFake(
  WidgetTester tester, {
  List<Override> extra = const [],
}) async {
  final fake = _FakeCfw();
  final c = ProviderContainer(
    overrides: [
      deviceServiceProvider.overrideWithValue(fake),
      dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
      ...extra,
    ],
  );

  addTearDown(c.dispose);

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
  await c.read(dataAssetsProvider.future);

  return (ref, c, fake);
}

void main() {
  group('review fixes', () {
    final info = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    testWidgets('connecting reads the loaded preset\'s scenes', (tester) async {
      final (ref, c, _) = await _withFake(tester);

      await tester.runAsync(() => refreshNamesThenCfw(ref));

      expect(c.read(sceneRecordsProvider)[3]?.sc1, {0: 33.0});
      expect(c.read(currentSceneProvider), 1);
    });

    testWidgets('turning Scenes on keeps a record the pedal already has', (
      tester,
    ) async {
      final (ref, c, fake) = await _withFake(
        tester,
        extra: [cfwInfoProvider.overrideWith((_) => info)],
      );

      await tester.runAsync(() => setModuleInScenes(ref, 3, isIn: true));

      expect(c.read(sceneRecordsProvider)[3]?.sc1, {0: 33.0});
      expect(fake.sentFrames.map((f) => f.toLowerCase()), [
        buildSceneRecordFrame(
          const SceneRecord(module: 3, sc1: {0: 33}),
        ).toLowerCase(),
      ]);
    });

    testWidgets('the pedal\'s scene push updates the live scene', (
      tester,
    ) async {
      final (ref, c, _) = await _withFake(
        tester,
        extra: [cfwInfoProvider.overrideWith((_) => info)],
      );

      handleHardwareSync(
        ref,
        InboundMessage.classify(
          buildSysexWriteFrame([0x12, 0x32, 0x01, 0x02, 0, 0, 0, 0]),
        ),
      );

      expect(c.read(currentSceneProvider), 2);
    });

    testWidgets('a failed state read drops the scenes too', (tester) async {
      final (ref, c, _) = await _withFake(
        tester,
        extra: [
          cfwInfoProvider.overrideWith((_) => info),
          currentSceneProvider.overrideWith((_) => 1),
          sceneRecordsProvider.overrideWith(
            (_) => {3: const SceneRecord(module: 3)},
          ),
        ],
      );

      await tester.runAsync(() => refreshDecodedState(ref));

      expect(c.read(sceneRecordsProvider), isEmpty);
      expect(c.read(currentSceneProvider), 0);
    });

    testWidgets('a pedal-side preset change drops the old scenes at once', (
      tester,
    ) async {
      final (ref, c, _) = await _withFake(
        tester,
        extra: [
          cfwInfoProvider.overrideWith((_) => info),
          presetLoadingProvider.overrideWith((_) => true),
          currentSceneProvider.overrideWith((_) => 1),
          sceneRecordsProvider.overrideWith(
            (_) => {3: const SceneRecord(module: 3)},
          ),
        ],
      );
      handleHardwareSync(
        ref,
        // The pedal's preset-selected notify (`12 43 <index>`).
        InboundMessage.classify(
          buildSysexWriteFrame([0x12, 0x43, 0x01, 0, 0, 0]),
        ),
      );

      expect(c.read(sceneRecordsProvider), isEmpty);
      expect(c.read(currentSceneProvider), 0);
    });
  });

  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<(WidgetRef, ProviderContainer, SilentTransport)> setUp(
    WidgetTester tester, {
    bool isCfw = true,
    int scene = 1,
    Map<int, SceneRecord> records = const {},
  }) async {
    final transport = SilentTransport();
    final service = DeviceService(transport)..startListening();
    final c = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(service),
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
        cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
        currentSceneProvider.overrideWith((_) => scene),
        sceneRecordsProvider.overrideWith((_) => records),
      ],
    );

    addTearDown(c.dispose);
    addTearDown(service.dispose);

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
    await c.read(dataAssetsProvider.future);

    return (ref, c, transport);
  }

  List<String> sent(SilentTransport t) =>
      t.sentFrames.map((f) => f.toLowerCase()).toList();

  testWidgets('a knob edit in SC1 sends the whole record and stores it', (
    tester,
  ) async {
    final (ref, c, t) = await setUp(
      tester,
      records: {
        3: const SceneRecord(module: 3, sc1: {0: 46}),
      },
    );

    await tester.runAsync(() => setSceneParam(ref, 3, 1, 96));

    expect(sent(t), [
      buildSceneRecordFrame(
        const SceneRecord(module: 3, sc1: {0: 46, 1: 96}),
      ).toLowerCase(),
    ]);
    expect(c.read(sceneRecordsProvider)[3]!.sc1, {0: 46.0, 1: 96.0});
  });

  testWidgets(
    'isSceneEdit: only in SC1/SC2, on a CFW, for a module in scenes',
    (tester) async {
      final (ref, _, _) = await setUp(
        tester,
        records: {3: const SceneRecord(module: 3)},
      );

      expect(isSceneEdit(ref, 3), isTrue);
      expect(isSceneEdit(ref, 0), isFalse); // NR is not in scenes

      final (base, _, _) = await setUp(
        tester,
        scene: 0,
        records: {3: const SceneRecord(module: 3)},
      );

      expect(isSceneEdit(base, 3), isFalse);

      final (stock, _, _) = await setUp(
        tester,
        isCfw: false,
        records: {3: const SceneRecord(module: 3)},
      );

      expect(isSceneEdit(stock, 3), isFalse);
    },
  );

  testWidgets('selecting a scene sends 11 32 and updates the provider', (
    tester,
  ) async {
    final (ref, c, t) = await setUp(tester, scene: 0);

    await tester.runAsync(() => selectScene(ref, 2));

    expect(sent(t), [selectSceneFrame(2).toLowerCase()]);
    expect(c.read(currentSceneProvider), 2);
  });

  testWidgets('adding a module to scenes and its on/off override', (
    tester,
  ) async {
    final (ref, c, t) = await setUp(tester);

    await tester.runAsync(() => setModuleInScenes(ref, 0, isIn: true));
    await tester.runAsync(() => setSceneModuleState(ref, 0, false));

    // The first switch-on asks the pedal for its records first (the scene
    // reads, with the preset's EXP slots).
    final reads = {
      readSceneRecordsFrame().toLowerCase(),
      readCurrentSceneFrame().toLowerCase(),
      readExpFrame().toLowerCase(),
    };

    expect(sent(t).where((f) => !reads.contains(f)), [
      buildSceneRecordFrame(const SceneRecord(module: 0)).toLowerCase(),
      buildSceneRecordFrame(
        const SceneRecord(module: 0, sc1On: false),
      ).toLowerCase(),
    ]);
    expect(c.read(sceneRecordsProvider)[0]!.sc1On, isFalse);
  });

  testWidgets('removing a module from scenes clears its record', (
    tester,
  ) async {
    final (ref, c, t) = await setUp(
      tester,
      records: {
        0: const SceneRecord(module: 0, sc1: {0: 23}),
      },
    );

    await tester.runAsync(() => setModuleInScenes(ref, 0, isIn: false));

    expect(sent(t), [clearSceneRecordFrame(0).toLowerCase()]);
    expect(c.read(sceneRecordsProvider).containsKey(0), isFalse);
  });

  testWidgets('stock firmware: refreshScenes sends nothing', (tester) async {
    final (ref, _, t) = await setUp(tester, isCfw: false);

    await tester.runAsync(() => refreshScenes(ref));

    expect(t.sentFrames, isEmpty);
  });

  testWidgets('clearSceneState drops the previous preset\'s scenes', (
    tester,
  ) async {
    final (ref, c, _) = await setUp(
      tester,
      scene: 2,
      records: {3: const SceneRecord(module: 3)},
    );

    clearSceneState(ref);

    expect(c.read(currentSceneProvider), 0);
    expect(c.read(sceneRecordsProvider), isEmpty);
  });
}
