import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/decoded_preset_state.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/test_assets.dart';
import '../support/view_helpers.dart';

/// The regular editor header. A user-named clone holds up to 15 characters
/// (CloUploadFrame.nameMaxChars); at the 692-px work area of the 960 minimum
/// it must ellipsize, never overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = loadTestDataAssets();

  Future<void> pumpEditor(
    WidgetTester tester, {
    required int moduleId,
    required int fxId,
    bool isCloneMode = false,
    Map<int, String> userNames = const {},
  }) async {
    final container = ProviderContainer(
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        currentSelectedEffectsProvider.overrideWith((_) => {moduleId: fxId}),
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
            data: const MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 692,
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
    );
  }

  testWidgets('a 15-character clone name ellipsizes in the header', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      moduleId: 9,
      fxId: 901,
      isCloneMode: true,
      userNames: const {901: 'WWWWWWWWWWWWWWW'},
    );

    expectNoOverflow(tester);

    final title = tester.getRect(find.text('AMP'));
    final effect = tester.getRect(find.byType(SonicDropdown<int>).first);
    final toggle = tester.getRect(find.byType(SonicToggle).first);

    expect(effect.left, greaterThanOrEqualTo(title.right));
    expect(effect.right, lessThanOrEqualTo(toggle.left));
  });

  // Regular (prototype N_Principal): tag, prev, selector, next, the amp's
  // band chip, then the on/off toggle pinned right, all on one line.
  testWidgets('AMP: tag, prev, selector, next, band chip, toggle', (
    tester,
  ) async {
    await pumpEditor(tester, moduleId: 3, fxId: 307);

    expectNoOverflow(tester);

    final rects = [
      tester.getRect(find.text('AMP')),
      tester.getRect(find.byKey(const Key('model-prev'))),
      tester.getRect(find.byType(SonicDropdown<int>).first),
      tester.getRect(find.byKey(const Key('model-next'))),
      tester.getRect(find.byKey(const Key('amp-band'))),
      tester.getRect(find.byType(SonicToggle).first),
    ];

    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      expect(rects[i].center.dy, closeTo(rects[2].center.dy, 0.01));
    }
    expect(rects[2].width, greaterThanOrEqualTo(220));
  });

  testWidgets('NR (one effect): a static name, no arrows', (tester) async {
    await pumpEditor(tester, moduleId: 0, fxId: 1);

    expect(find.text(assets.effects.byId(1)!.name), findsOneWidget);
    expect(find.byKey(const Key('model-prev')), findsNothing);
    expect(find.byKey(const Key('model-next')), findsNothing);
  });
}
