import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

void main() {
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
      records: {3: const SceneRecord(module: 3, sc1: {0: 46})},
    );

    await tester.runAsync(() => setSceneParam(ref, 3, 1, 96));

    expect(sent(t), [
      buildSceneRecordFrame(
        const SceneRecord(module: 3, sc1: {0: 46, 1: 96}),
      ).toLowerCase(),
    ]);
    expect(c.read(sceneRecordsProvider)[3]!.sc1, {0: 46.0, 1: 96.0});
  });

  testWidgets('isSceneEdit: only in SC1/SC2, on a CFW, for a module in scenes', (
    tester,
  ) async {
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
  });

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

    expect(sent(t), [
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
      records: {0: const SceneRecord(module: 0, sc1: {0: 23})},
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
