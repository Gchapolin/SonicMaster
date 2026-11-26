import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/l10n/shell_text.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/block_panel.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

/// The regular editor's right-hand panel (prototype N_Principal, 236 wide):
/// block on, Clone Mode (amp), user slots (cab), footswitch, scenes, EXP,
/// the effect's non-knob params and its description.
void main() {
  final assets = loadTestDataAssets();

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    required int moduleId,
    required int fxId,
    Map<int, num> params = const {},
  }) async {
    final container = ProviderContainer(
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(SilentTransport())..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        connectionStateProvider.overrideWith((_) => true),
        currentSelectedEffectsProvider.overrideWith((_) => {moduleId: fxId}),
        currentParametersProvider.overrideWith((_) => {moduleId: params}),
        currentPresetStateProvider.overrideWith((_) => loadedPresetState),
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
            data: const MediaQueryData(size: Size(800, 1000)),
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => Align(
                    alignment: .topLeft,
                    child: SingleChildScrollView(child: BlockPanel(moduleId)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return container;
  }

  testWidgets('the panel is 236 wide', (tester) async {
    await pumpPanel(tester, moduleId: 0, fxId: 1);

    expect(tester.getSize(find.byType(BlockPanel)).width, 236);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clone switch only on the amp', (tester) async {
    await pumpPanel(tester, moduleId: 3, fxId: 308);
    expect(find.text(ShellText.current.cloneMode), findsOneWidget);

    await pumpPanel(tester, moduleId: 0, fxId: 1);
    expect(find.text(ShellText.current.cloneMode), findsNothing);
  });

  testWidgets('user slots button only on the cab', (tester) async {
    await pumpPanel(tester, moduleId: 4, fxId: 410);
    expect(find.text(ShellText.current.userSlots), findsOneWidget);

    await pumpPanel(tester, moduleId: 3, fxId: 308);
    expect(find.text(ShellText.current.userSlots), findsNothing);

    await pumpPanel(tester, moduleId: 0, fxId: 1);
    expect(find.text(ShellText.current.userSlots), findsNothing);
  });

  testWidgets('block on reflects and toggles the module', (tester) async {
    final c = await pumpPanel(tester, moduleId: 0, fxId: 1);
    final toggle = find.byKey(const Key('block-on'));

    expect(find.text(ShellText.current.blockOn), findsOneWidget);
    expect(tester.widget<SonicToggle>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();

    expect(c.read(currentPresetStateProvider)!.moduleStates['NR'], isFalse);
  });

  testWidgets('the footswitch is None / FS1 / FS2', (tester) async {
    await pumpPanel(tester, moduleId: 0, fxId: 1);

    expect(find.text(ShellText.current.footSwitch.toUpperCase()), findsOne);
    expect(find.text(ShellText.current.none.toUpperCase()), findsOneWidget);
    expect(find.text('FS1'), findsOneWidget);
    expect(find.text('FS2'), findsOneWidget);
  });

  testWidgets('the panel lists the non-knob params', (tester) async {
    final def = assets.effects.effects.values.firstWhere(
      (d) => d.params.any(
        (p) => p.widgetType == .select && (p.options ?? []).isNotEmpty,
      ),
    );
    final select = def.params.firstWhere((p) => p.widgetType == .select);
    final moduleId = def.id ~/ 100;

    await pumpPanel(tester, moduleId: moduleId, fxId: def.id);

    expect(find.text(select.name.toUpperCase()), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BlockPanel),
        matching: find.byType(SonicDropdown<int>),
      ),
      findsWidgets,
    );
    expect(find.text(select.options![0]), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the description is the effect's", (tester) async {
    final def = assets.effects.byId(308)!;

    expect(def.descriptionEn, isNotEmpty);
    await pumpPanel(tester, moduleId: 3, fxId: 308);

    expect(find.text(def.descriptionEn), findsOneWidget);
  });

  // The user's iPad in landscape: the header, the whole piece and the value
  // line show without scrolling, the panel fully visible beside them.
  for (final size in const [Size(1180, 820), Size(1194, 834)]) {
    for (final (name, module) in const [('pedal', 0), ('amp', 3)]) {
      testWidgets('$name fits ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        final c = await pumpPage(
          tester,
          size: size,
          selectedEffects: fullPresetEffects,
        );

        c.read(selectedModuleProvider.notifier).state = module;
        await tester.pump();

        final screen = Offset.zero & size;

        bool inside(Rect r) =>
            screen.contains(r.topLeft) &&
            screen.contains(r.bottomRight - const Offset(0.01, 0.01));

        final piece = find.descendant(
          of: find.byType(ModuleEditor),
          matching: find.byType(GearPiece),
        );

        expect(inside(tester.getRect(piece)), isTrue);
        expect(
          inside(tester.getRect(find.byKey(const Key('piece-value')))),
          isTrue,
        );
        expect(inside(tester.getRect(find.byType(BlockPanel))), isTrue);
        // Nothing scrolls: not the work area, not the editor or the panel.
        final editor = find.byType(ModuleEditor);
        final scrollables = [
          ...tester.stateList<ScrollableState>(
            find.ancestor(of: editor, matching: find.byType(Scrollable)),
          ),
          ...tester.stateList<ScrollableState>(
            find.descendant(of: editor, matching: find.byType(Scrollable)),
          ),
        ];

        expect(scrollables, isNotEmpty);
        for (final s in scrollables) {
          expect(s.position.maxScrollExtent, 0);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('regular: the header has no on/off toggle of its own', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1180, 820),
      selectedEffects: fullPresetEffects,
    );

    final editorToggles = find.descendant(
      of: find.byType(ModuleEditor),
      matching: find.byType(SonicToggle),
    );
    final panelToggles = find.descendant(
      of: find.byType(BlockPanel),
      matching: find.byType(SonicToggle),
    );

    expect(editorToggles.evaluate().length, panelToggles.evaluate().length);
  });
}
