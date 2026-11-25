import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/view_helpers.dart';

void main() {
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<(ProviderContainer, SilentTransport)> pump(
    WidgetTester tester, {
    bool isCfw = true,
    int scene = 0,
    Map<int, SceneRecord> records = const {},
    Size size = const Size(1280, 800),
  }) async {
    final transport = SilentTransport();
    final c = await pumpPage(
      tester,
      size: size,
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
        currentSceneProvider.overrideWith((_) => scene),
        sceneRecordsProvider.overrideWith((_) => records),
      ],
    );

    return (c, transport);
  }

  Finder inEditor(Finder f) =>
      find.descendant(of: find.byType(ModuleEditor), matching: f);

  testWidgets('stock firmware: no scene controls', (tester) async {
    await pump(tester, isCfw: false);

    expect(inEditor(find.text('SCENES')), findsNothing);
  });

  testWidgets('CFW, module not in scenes: only the Scenes switch', (
    tester,
  ) async {
    await pump(tester);

    expect(inEditor(find.text('SCENES')), findsOneWidget);
    expect(inEditor(find.text('SC1')), findsNothing);
  });

  testWidgets('in SC1 the knob shows the scene value and the scene controls', (
    tester,
  ) async {
    await pump(
      tester,
      scene: 1,
      records: {
        0: const SceneRecord(module: 0, sc1: {0: 23}),
      },
    );

    expect(inEditor(find.text('23')), findsOneWidget); // THRE: base is 50
    expect(inEditor(find.text('SC1')), findsOneWidget);
    expect(inEditor(find.text('SC2')), findsOneWidget);
    expect(inEditor(find.text('ON')), findsOneWidget);
    expect(inEditor(find.text('OFF')), findsOneWidget);
  });

  testWidgets('in BASE the knob keeps the base value', (tester) async {
    await pump(
      tester,
      records: {
        0: const SceneRecord(module: 0, sc1: {0: 23}),
      },
    );

    expect(inEditor(find.text('50')), findsOneWidget);
    expect(inEditor(find.text('OFF')), findsNothing); // no override in BASE
  });

  testWidgets('a scene value for a knob the effect lacks is ignored', (
    tester,
  ) async {
    await pump(
      tester,
      scene: 1,
      records: {
        0: const SceneRecord(module: 0, sc1: {6: 99}),
      },
    );

    expect(tester.takeException(), isNull);
    expect(inEditor(find.text('50')), findsOneWidget);
  });

  testWidgets('OFF sends the record with the SC1 off flags', (tester) async {
    final (_, transport) = await pump(
      tester,
      scene: 1,
      records: {
        0: const SceneRecord(module: 0, sc1: {0: 23}),
      },
    );

    await tester.ensureVisible(inEditor(find.text('OFF')));
    await tester.pump();
    await tester.tap(inEditor(find.text('OFF')));
    await tester.pump();

    expect(
      transport.sentFrames.map((f) => f.toLowerCase()),
      contains(
        buildSceneRecordFrame(
          const SceneRecord(module: 0, sc1On: false, sc1: {0: 23}),
        ).toLowerCase(),
      ),
    );
  });

  testWidgets('picking SC2 selects it on the pedal', (tester) async {
    final (c, transport) = await pump(
      tester,
      scene: 1,
      records: {0: const SceneRecord(module: 0)},
    );

    await tester.ensureVisible(inEditor(find.text('SC2')));
    await tester.pump();
    await tester.tap(inEditor(find.text('SC2')));
    await tester.pump();

    expect(
      transport.sentFrames.map((f) => f.toLowerCase()),
      contains(selectSceneFrame(2).toLowerCase()),
    );
    expect(c.read(currentSceneProvider), 2);
  });

  testWidgets('setParameter in SC1 writes the scene, not the base', (
    tester,
  ) async {
    final (c, transport) = await pump(
      tester,
      scene: 1,
      records: {0: const SceneRecord(module: 0)},
    );
    final ref = tester.element(find.byType(ModuleEditor)) as WidgetRef;

    await tester.runAsync(() => setParameter(ref, 0, 0, 30));

    expect(transport.sentFrames.map((f) => f.toLowerCase()), [
      buildSceneRecordFrame(
        const SceneRecord(module: 0, sc1: {0: 30}),
      ).toLowerCase(),
    ]);
    expect(c.read(currentParametersProvider)[0]![0], 50); // base untouched
  });

  testWidgets('phone: the scene controls fit', (tester) async {
    await pump(
      tester,
      scene: 1,
      size: const Size(956, 440),
      records: {
        0: const SceneRecord(module: 0, sc1: {0: 23}),
      },
    );

    expectNoOverflow(tester);
  });

  group('in Portuguese', () {
    setUp(() => appLang = Lang.pt);
    tearDown(() => appLang = Lang.en);

    testWidgets('820x1180: the scene controls read in Portuguese and fit', (
      tester,
    ) async {
      await pump(
        tester,
        scene: 1,
        size: const Size(820, 1180),
        records: {
          0: const SceneRecord(module: 0, sc1: {0: 23}),
        },
      );

      expectNoOverflow(tester);
      expect(inEditor(find.text('CENAS')), findsOneWidget);
      expect(inEditor(find.text('SEGUIR')), findsOneWidget);
      expect(inEditor(find.text('LIGADO')), findsOneWidget);
      expect(inEditor(find.text('DESLIGADO')), findsOneWidget);
    });
  });
}
