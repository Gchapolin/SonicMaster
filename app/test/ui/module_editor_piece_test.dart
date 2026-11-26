import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sonicmaster/ui/knob_mapping.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/l10n/amp_text.dart';
import 'package:sonicmaster/model/amp_gain.dart';
import 'package:sonicmaster/model/decoded_preset_state.dart';
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
    DecodedPresetState state = loadedPresetState,
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
        currentPresetStateProvider.overrideWith((_) => state),
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
    expect(piece.fit, pieceFit);
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

  // The value line under the piece: the last-touched knob, as KnobControl
  // printed it ("<value><unit>" or the data's text).
  Finder valueLine(String text) => find.descendant(
    of: find.byKey(const Key('piece-value')),
    matching: find.text(text),
  );

  testWidgets('the value line starts on the first knob', (tester) async {
    await pumpEditor(tester, moduleId: 1, fxId: 104, params: {0: 30, 1: 0.5});

    expect(valueLine('Depth'), findsOneWidget);
    expect(valueLine('30'), findsOneWidget);
  });

  testWidgets('dragging a knob updates the line with its formatted value', (
    tester,
  ) async {
    await pumpEditor(tester, moduleId: 1, fxId: 104, params: {0: 30, 1: 0.5});

    // Auto Wah's 2nd knob: Rate, 0.1..10 Hz, step 0.1.
    await tester.drag(pieceKnob(1), const Offset(0, -40));
    await tester.pump();

    expect(valueLine('Rate'), findsOneWidget);
    final line = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('piece-value')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .last!;
    expect(line, endsWith('Hz'));
    expect(double.parse(line.replaceAll('Hz', '')), greaterThan(0.5));
  });

  testWidgets('tapping the value and typing one sends it to the knob', (
    tester,
  ) async {
    final (c, transport) = await pumpEditor(
      tester,
      moduleId: 0,
      fxId: 1,
      params: {0: 50},
    );

    await tester.tap(valueLine('50'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '72');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(transport.sentFrames, [
      assets.commands.parameterCommand(0, 0, '72'),
    ]);
    expect(c.read(currentParametersProvider)[0]![0], 72);
    expect(valueLine('72'), findsOneWidget);
    final piece = tester.widget<GearPiece>(find.byType(GearPiece));
    expect(piece.values![0], 72);
  });

  testWidgets('a decimal comma is read as a point (pt-BR keyboard)', (
    tester,
  ) async {
    // The first effect whose first piece knob has a fractional step.
    final def = assets.effects.effects.values.firstWhere(
      (d) =>
          d.id < 1000 &&
          pieceKnobs(d).isNotEmpty &&
          pieceKnobs(d).first.step != null &&
          pieceKnobs(d).first.step != pieceKnobs(d).first.step!.roundToDouble(),
    );
    final knob = pieceKnobs(def).first;
    final (c, _) = await pumpEditor(
      tester,
      moduleId: def.id ~/ 100,
      fxId: def.id,
      params: {knob.algId: knob.min ?? 0},
    );

    await tester.tap(find.byKey(const Key('piece-value')).hitTestable());
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '1,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(c.read(currentParametersProvider)[def.id ~/ 100]![knob.algId], 1.5);
  });

  testWidgets('the value line is a 44x44 tap target', (tester) async {
    await pumpEditor(tester, moduleId: 0, fxId: 1, params: {0: 50});

    final line = tester.getRect(find.byKey(const Key('piece-value')));

    expect(line.width, greaterThanOrEqualTo(44));
    expect(line.height, greaterThanOrEqualTo(44));

    // Its corners (inside by 2 px) open the editor, not only the digits.
    for (final p in [
      line.topLeft + const Offset(2, 2),
      line.bottomRight - const Offset(2, 2),
    ]) {
      await tester.tapAt(p);
      await tester.pump();
      expect(find.byType(EditableText), findsOneWidget, reason: '$p');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
  });

  testWidgets('a piece with no knob params ignores knob drags', (tester) async {
    var sets = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            child: PieceEditor(
              model: 'No Such Model',
              kind: GearKind.pedal,
              knobs: const [],
              values: const {},
              isOn: true,
              isEnabled: true,
              onSet: (p, v) => sets++,
              onSwitch: () {},
            ),
          ),
        ),
      ),
    );

    final knobs = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is GearKnobPainter,
    );

    expect(knobs, findsWidgets); // the generic piece draws placeholders
    await tester.drag(knobs.first, const Offset(0, -40));
    await tester.pump();

    expect(sets, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a typed value out of range is clamped', (tester) async {
    final (c, _) = await pumpEditor(
      tester,
      moduleId: 0,
      fxId: 1,
      params: {0: 50},
    );

    await tester.tap(valueLine('50'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(c.read(currentParametersProvider)[0]![0], 100);
  });

  testWidgets('a synced Rate leaves the piece; its divisions stay', (
    tester,
  ) async {
    final (_, transport) = await pumpEditor(
      tester,
      moduleId: 1,
      fxId: 104,
      params: {1: 4, 6: 1},
    );

    final piece = tester.widget<GearPiece>(find.byType(GearPiece));
    expect(piece.knobNames, isNot(contains('Rate')));
    expect(piece.values!.length, piece.knobNames!.length);

    final rate = find.descendant(
      of: find.byKey(const ValueKey('param:Rate')),
      matching: find.byType(SonicDropdown<int>),
    );
    tester.widget<SonicDropdown<int>>(rate).onChanged(7);
    await tester.pump();
    expect(transport.sentFrames, [assets.commands.parameterCommand(1, 1, '7')]);
  });

  testWidgets('clone amp: the piece is the amp, edits go to 9, on/off to 3', (
    tester,
  ) async {
    final (c, transport) = await pumpEditor(
      tester,
      moduleId: 9,
      fxId: 901,
      params: {0: 50},
      state: loadedPresetState.copyWith(isCloneMode: true),
    );

    final piece = tester.widget<GearPiece>(find.byType(GearPiece));
    expect(piece.kind, GearKind.amp);

    await tester.drag(pieceKnob(0), const Offset(0, -60));
    await tester.pump();
    final sent = c.read(currentParametersProvider)[9]![0]!;
    expect(sent, greaterThan(50));
    expect(transport.sentFrames.first, isNotNull);

    transport.sentFrames.clear();
    await tester.tap(find.byKey(const Key('jewel')));
    await tester.pump();
    expect(transport.sentFrames, [assets.commands.moduleOff(3)]);
    expect(c.read(currentPresetStateProvider)!.moduleStates['AMP'], false);
  });
}
