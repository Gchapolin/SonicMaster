import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/footswitch_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_io.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

/// Records every frame; every read times out (null).
class _Spy extends DeviceService {
  _Spy() : super(SilentTransport());

  final sent = <String>[];

  @override
  Future<void> sendFrame(String frameHex) async =>
      sent.add(frameHex.toLowerCase());

  @override
  Future<String?> requestStateDump({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestSceneRecords({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestCurrentScene({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestExpAssigns({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

ImportedPreset _preset({
  ({int fs1, int fs2})? footswitch,
  Map<int, SceneRecord>? scenes,
}) => ImportedPreset(
  isCloneMode: false,
  presetVolume: 75,
  presetBpm: 120,
  moduleStates: const {0: true},
  selectedEffects: const {0: 1},
  parameters: const {
    0: {0: 8},
  },
  chainOrder: const ['NR'],
  warnings: const [],
  footswitch: footswitch,
  scenes: scenes,
);

Future<(WidgetRef, _Spy)> _pump(
  WidgetTester tester, {
  bool isCfw = true,
  Map<int, SceneRecord> records = const {},
}) async {
  final spy = _Spy();
  final c = ProviderContainer(
    overrides: [
      deviceServiceProvider.overrideWithValue(spy),
      dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
      cfwInfoProvider.overrideWith(
        (_) => isCfw ? decodeCfwSettingsFrame(cfwSettingsOriginal) : null,
      ),
      sceneRecordsProvider.overrideWith((_) => records),
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

  return (ref, spy);
}

String _fs(int module, {required bool isFs2, required bool isOn}) =>
    FootswitchFrame.build(
      moduleId: module,
      isFs2: isFs2,
      isOn: isOn,
    ).toLowerCase();

/// Every footswitch write there is (9 modules x 2 switches x on/off).
final _allFs = {
  for (var m = 0; m < 9; m++)
    for (final isFs2 in [false, true])
      for (final isOn in [false, true]) _fs(m, isFs2: isFs2, isOn: isOn),
};

void main() {
  testWidgets('footswitch masks set every module on FS1 and FS2', (
    tester,
  ) async {
    final (ref, spy) = await _pump(tester);

    await tester.runAsync(
      () => pushImportedPreset(ref, _preset(footswitch: (fs1: 0x02, fs2: 0))),
    );

    expect(spy.sent, contains(_fs(1, isFs2: false, isOn: true)));
    expect(spy.sent, contains(_fs(0, isFs2: false, isOn: false)));
    expect(spy.sent, contains(_fs(1, isFs2: true, isOn: false)));
    expect(spy.sent.where(_allFs.contains), hasLength(18));
  });

  testWidgets('no footswitch in the file: the assignment is left alone', (
    tester,
  ) async {
    final (ref, spy) = await _pump(tester);

    await tester.runAsync(() => pushImportedPreset(ref, _preset()));

    expect(spy.sent.where(_allFs.contains), isEmpty);
  });

  testWidgets('CFW: writes the file\'s scenes and clears the old ones', (
    tester,
  ) async {
    const kept = SceneRecord(module: 1, sc1: {0: 20});
    final (ref, spy) = await _pump(
      tester,
      records: const {6: SceneRecord(module: 6)},
    );

    await tester.runAsync(
      () => pushImportedPreset(ref, _preset(scenes: const {1: kept})),
    );

    expect(spy.sent, contains(buildSceneRecordFrame(kept).toLowerCase()));
    expect(spy.sent, contains(clearSceneRecordFrame(6).toLowerCase()));
  });

  testWidgets('stock firmware: no scene writes', (tester) async {
    final (ref, spy) = await _pump(tester, isCfw: false);

    await tester.runAsync(
      () => pushImportedPreset(
        ref,
        _preset(scenes: const {1: SceneRecord(module: 1)}),
      ),
    );

    expect(
      spy.sent,
      isNot(
        contains(
          buildSceneRecordFrame(const SceneRecord(module: 1)).toLowerCase(),
        ),
      ),
    );
  });
}
