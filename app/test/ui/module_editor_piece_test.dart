import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/l10n/amp_text.dart';
import 'package:sonicmaster/model/amp_gain.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

/// The regular editor: the selected module's big piece, edited in place, with
/// prev / next around the model selector.
void main() {
  final assets = loadTestDataAssets();

  Future<(ProviderContainer, SilentTransport)> pumpEditor(
    WidgetTester tester, {
    required int moduleId,
    required int fxId,
    Map<int, num> params = const {},
  }) async {
    final transport = SilentTransport();
    final container = ProviderContainer(
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        currentSelectedEffectsProvider.overrideWith((_) => {moduleId: fxId}),
        currentParametersProvider.overrideWith((_) => {moduleId: params}),
        currentPresetStateProvider.overrideWith((_) => loadedPresetState),
      ],
    );

    addTearDown(container.dispose);
    await container.read(dataAssetsProvider.future);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: .ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 1000)),
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 900,
                      child: SingleChildScrollView(
                        child: ModuleEditor(moduleId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return (container, transport);
  }

  Finder pieceKnob(int i) => find
      .byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GearKnobPainter,
      )
      .at(i);

  // setEffectType re-reads the state dump after the switch; the silent pedal
  // never answers, so run its waits out.
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {});
    }
  }

  testWidgets('the editor shows the selected model as its big piece', (
    tester,
  ) async {
    await pumpEditor(tester, moduleId: 3, fxId: 308, params: {0: 20});

    final piece = tester.widget<GearPiece>(find.byType(GearPiece));

    expect(piece.model, 'Brit 800');
    expect(piece.kind, GearKind.amp);
    expect(piece.fit, const Size(660, 440));
    // The effect's own knob names, in its order.
    final knobs = assets.effects
        .byId(308)!
        .params
        .where((p) => p.widgetType == .knob)
        .toList();
    expect(piece.knobNames, [for (final p in knobs) p.name]);
    expect(piece.values!.length, knobs.length);
  });

  testWidgets('dragging a knob on the piece sends setParameter', (
    tester,
  ) async {
    final (c, transport) = await pumpEditor(
      tester,
      moduleId: 0,
      fxId: 1,
      params: {0: 50},
    );
    final thre = assets.effects.byId(1)!.params.first;

    await tester.drag(pieceKnob(0), const Offset(0, -60));
    await tester.pump();

    expect(transport.sentFrames, isNotEmpty);
    final sent = c.read(currentParametersProvider)[0]![thre.algId]!;
    expect(sent, greaterThan(50));
    expect(sent, sent.roundToDouble()); // rounded to the step
  });

  testWidgets('the footswitch on the piece toggles the module', (tester) async {
    final (c, transport) = await pumpEditor(tester, moduleId: 0, fxId: 1);

    await tester.tap(find.byKey(const Key('footswitch')));
    await tester.pump();

    expect(transport.sentFrames, [assets.commands.moduleOff(0)]);
    expect(c.read(currentPresetStateProvider)!.moduleStates['NR'], false);
  });

  testWidgets('prev/next walk the model list', (tester) async {
    final (_, transport) = await pumpEditor(tester, moduleId: 3, fxId: 308);
    final list = byAmpGain(assets.commands.effectIdsFor(3));
    final i = list.indexOf(308);

    await tester.tap(find.byKey(const Key('model-next')));
    await tester.pump();
    expect(
      transport.sentFrames.first,
      assets.commands.effectType(3, list[i + 1]),
    );
    await drain(tester);
  });

  testWidgets('prev from the first model wraps to the last', (tester) async {
    final list = byAmpGain(assets.commands.effectIdsFor(3));
    final (_, transport) = await pumpEditor(
      tester,
      moduleId: 3,
      fxId: list.first,
    );

    await tester.tap(find.byKey(const Key('model-prev')));
    await tester.pump();
    expect(
      transport.sentFrames.first,
      assets.commands.effectType(3, list.last),
    );
    await drain(tester);
  });

  testWidgets('the amp list keeps the bands', (tester) async {
    await pumpEditor(tester, moduleId: 3, fxId: 308);

    final dropdown = tester.widget<SonicDropdown<int>>(
      find.byType(SonicDropdown<int>).first,
    );

    expect(dropdown.sections.values, [
      for (final g in AmpGain.values) AmpText.current.band(g),
    ]);
    // The band chip names the current amp's band.
    expect(
      find.text(AmpText.current.band(AmpGain.rockLead).toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('a pedal has no band chip', (tester) async {
    await pumpEditor(tester, moduleId: 2, fxId: 201);

    for (final g in AmpGain.values) {
      expect(find.text(AmpText.current.band(g).toUpperCase()), findsNothing);
    }
  });
}
