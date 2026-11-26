import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/model/decoded_preset_state.dart';
import 'package:sonicmaster/model/footswitch_assignment.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../support/test_assets.dart';
import '../support/view_helpers.dart';

/// The module editor at compact density: 72-px knobs, a 40-px header, 32-px
/// controls, slimmer foot-switch segments and no description. Editor widths are
/// those of real compact work areas (viewport - 2 x 8 padding - 194 Preset
/// panel - 8 gap): 634 at 852 wide, 548 at 780, 422 at the 640 minimum.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = loadTestDataAssets();

  Future<void> pumpEditor(
    WidgetTester tester, {
    required int moduleId,
    required int fxId,
    double width = 634,
    SonicMetrics metrics = SonicMetrics.compact,
    Map<int, num> params = const {},
    bool isCloneMode = false,
    Map<int, String> userNames = const {},
    Size screen = const Size(800, 600),
  }) async {
    final container = ProviderContainer(
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        currentSelectedEffectsProvider.overrideWith((_) => {moduleId: fxId}),
        currentParametersProvider.overrideWith((_) => {moduleId: params}),
        currentPresetStateProvider.overrideWith(
          (_) => DecodedPresetState(
            isCloneMode: isCloneMode,
            presetVolume: 44,
            presetBpm: 120,
            moduleStates: const {},
            chainOrder: const [],
          ),
        ),
        userNamesProvider.overrideWith((_) => userNames),
      ],
    );

    addTearDown(container.dispose);
    await container.read(dataAssetsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: .ltr,
          child: MediaQuery(
            data: MediaQueryData(size: screen),
            child: SonicMetricsScope(
              metrics: metrics,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: SonicSurface(
                      padding: EdgeInsets.zero,
                      child: ModuleEditor(moduleId),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The header ends where the control Wrap begins.
  double headerHeight(WidgetTester tester) =>
      tester.getTopLeft(find.byType(Wrap).first).dy -
      tester.getTopLeft(find.byType(ModuleEditor)).dy;

  Iterable<Size> dials(WidgetTester tester) =>
      find.byKey(const Key('knob')).evaluate().map((element) => element.size!);

  Finder inCell(String label, Type type) => find.descendant(
    of: find.byWidgetPredicate((w) => w is PanelCell && w.label == label),
    matching: find.byType(type),
  );

  for (final (metrics, dial, header) in const [
    (SonicMetrics.compact, 72.0, 40.0), // 4 + 32-px dropdown + 4
  ]) {
    final mode = metrics.isCompact ? 'compact' : 'regular';

    testWidgets(
      '$mode: ${dial.toInt()}-px knobs under a ${header.toInt()}-px header',
      (tester) async {
        await pumpEditor(tester, moduleId: 3, fxId: 307, metrics: metrics);

        expect(dials(tester), everyElement(Size.square(dial)));
        expect(headerHeight(tester), header);
        expect(
          tester.getSize(find.byType(SonicDropdown<int>).first).height,
          metrics.editorControlHeight,
        );
        expect(
          find.text(assets.effects.byId(307)!.descriptionEn),
          metrics.isCompact ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  // Regular draws the knobs on the piece (prototype N_Principal): no dials,
  // the piece under a 56-px header (12 + 40-px selector + 4) and its 8-px
  // padding, scaled down to the editor's width.
  testWidgets('regular: the knobs are on the piece under a 56-px header', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      moduleId: 3,
      fxId: 307,
      metrics: SonicMetrics.regular,
    );

    expect(dials(tester), isEmpty);
    expect(
      tester.getTopLeft(find.byType(GearPiece)).dy -
          tester.getTopLeft(find.byType(ModuleEditor)).dy,
      56 + 8,
    );
    // Scaled down to the room inside the surface's 1-px border, beside the
    // block panel (236 + 16 right padding), less the 16-px side padding.
    expect(tester.getRect(find.byType(GearPiece)).width, 634 - 2 - 252 - 32);
    expect(
      tester.getSize(find.byType(SonicDropdown<int>).first).height,
      SonicMetrics.regular.editorControlHeight,
    );
    expect(find.text(assets.effects.byId(307)!.descriptionEn), findsOneWidget);
  });

  testWidgets('compact: 32-px panel controls and slimmer FS segments', (
    tester,
  ) async {
    await pumpEditor(tester, moduleId: 9, fxId: 901, isCloneMode: true);

    final footswitch = find.byType(SonicSegmented<FootswitchAssignment>);

    expect(tester.getSize(inCell('Clone Mode', SonicToggle)).height, 32);
    expect(
      tester.getSize(find.widgetWithText(SonicButton, 'Load…')).height,
      32,
    );
    expect(
      tester
          .widget<SonicSegmented<FootswitchAssignment>>(footswitch)
          .segmentPadding,
      10,
    );
    // NONE / FS1 / FS2 at 10 px a side, in a 4-px cell padding: 44 px
    // narrower than the regular 196.1-px cell.
    expect(
      tester
          .getSize(
            find.ancestor(of: footswitch, matching: find.byType(PanelCell)),
          )
          .width,
      closeTo(152.1, 0.1),
    );
  });

  testWidgets('compact: the synced Rate division dropdown is 32 tall', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      moduleId: 1,
      fxId: 104,
      params: const {1: 4, 6: 1},
    );

    expect(tester.getSize(inCell('Rate', SonicDropdown<int>)).height, 32);
  });

  testWidgets('compact: the tap-tempo division dropdown is 32 tall', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      moduleId: 7,
      fxId: 708,
      params: const {1: 500, 6: 0},
    );

    expect(tester.getSize(find.byType(SonicDropdown<double>)).height, 32);
    expect(tester.getSize(find.widgetWithText(SonicButton, 'TAP')).height, 44);

    // Cancels TapTempoControl's beat timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // The other non-knob controls follow the metrics' control height too: a
  // toggle parameter, a select parameter and the IR file buttons. (The Clone
  // Mode toggle, the clone buttons and the division dropdowns are pinned
  // above.) Compact only: regular keeps them in the block panel, at the
  // prototype's sizes (block_panel_test.dart).
  testWidgets('compact: a toggle parameter is 32 tall', (tester) async {
    // FX1 Auto Wah: its Sync toggle.
    await pumpEditor(tester, moduleId: 1, fxId: 104);

    expect(tester.getSize(inCell('Sync', SonicToggle)).height, 32);
  });

  testWidgets('compact: a select parameter dropdown is 32 tall', (
    tester,
  ) async {
    // FX1 Touch Wah: its Mode select (Guitar / Bass).
    await pumpEditor(tester, moduleId: 1, fxId: 103);

    expect(tester.getSize(inCell('Mode', SonicDropdown<int>)).height, 32);
  });

  testWidgets('compact: the IR file buttons are 32 tall', (tester) async {
    await pumpEditor(tester, moduleId: 4, fxId: 416);

    for (final label in const ['Load…', 'Name…', 'Clear']) {
      expect(
        tester.getSize(find.widgetWithText(SonicButton, label)).height,
        32,
        reason: label,
      );
    }
  });

  // (name, moduleId, fxId, params, isCloneMode)
  const editors = [
    ('AMP Brit 50JP', 3, 307, <int, num>{}, false),
    ('Clone User Profile 1', 9, 901, <int, num>{}, true),
    ('IR User IR 1', 4, 416, <int, num>{}, false),
    ('DLY Sweep + tap tempo', 7, 708, <int, num>{1: 500, 6: 0}, false),
    ('FX1 Auto Wah, synced', 1, 104, <int, num>{1: 4, 6: 1}, false),
  ];

  group('no overflow at compact editor widths', () {
    for (final width in const [634.0, 548.0, 422.0]) {
      for (final (name, moduleId, fxId, params, isCloneMode) in editors) {
        testWidgets('$name at ${width.toInt()}', (tester) async {
          await pumpEditor(
            tester,
            moduleId: moduleId,
            fxId: fxId,
            width: width,
            params: params,
            isCloneMode: isCloneMode,
          );

          expectNoOverflow(tester);
          expect(dials(tester), everyElement(const Size.square(72)));

          // Cancels the DLY beat timer; harmless for the others.
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }

      testWidgets('a 15-char clone name at ${width.toInt()}', (tester) async {
        await pumpEditor(
          tester,
          moduleId: 9,
          fxId: 901,
          width: width,
          isCloneMode: true,
          userNames: const {901: 'WWWWWWWWWWWWWWW'},
        );

        expectNoOverflow(tester);
      });
    }
  });

  testWidgets('CFW slots 6-10 get the file actions of slots 1-5', (
    tester,
  ) async {
    await pumpEditor(tester, moduleId: 4, fxId: 422);
    expect(find.text('Load…'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

    await pumpEditor(tester, moduleId: 9, fxId: 910, isCloneMode: true);
    expect(find.text('Load…'), findsOneWidget);

    // The factory cab between the two IR ranges has none.
    await pumpEditor(tester, moduleId: 4, fxId: 421);
    expect(find.text('Load…'), findsNothing);
  });

  for (final width in const [422.0, 634.0]) {
    testWidgets('compact editor shows the piece fitted to the width $width', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        moduleId: 3,
        fxId: 307,
        width: width,
        screen: const Size(820, 1180),
      );

      expect(find.byType(GearPiece), findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.byType(GearPiece),
                matching: find.byType(FittedBox),
              ),
            )
            .width,
        lessThanOrEqualTo(width),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
