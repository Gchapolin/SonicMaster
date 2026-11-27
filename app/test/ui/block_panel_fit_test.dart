import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/block_panel.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/test_assets.dart';

/// Every effect of every module at the user's iPad (1180x820 landscape): the
/// header, the piece, its value line and the block panel fit without
/// scrolling on stock firmware; on the CFW in BASE the panel scrolls 64 px
/// at most (cab bands, DLY tap tempo beside scenes and EXP). In SC1 with the
/// module in scenes and on an EXP slot, the piece and its value line still
/// show; only the panel may scroll, within its own bounds (at this writing
/// the DLY models and Voks 30TB, by 17-92 px).
void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
  const size = Size(1180, 820);

  // (stock / CFW BASE / CFW SC1 + EXP)
  const modes = ['stock', 'CFW base', 'CFW SC1 + EXP'];

  Future<void> pumpEffect(
    WidgetTester tester,
    String mode,
    int moduleId,
    int fxId,
  ) async {
    final physId = moduleId == 9 ? 3 : moduleId;
    final isCfw = mode != 'stock';
    final isSc1 = mode == 'CFW SC1 + EXP';
    final knob = assets.effects
        .byId(fxId)!
        .paramsFor(isCfw: isCfw)
        .where((p) => p.widgetType == .knob)
        .firstOrNull;
    final c = await pumpPage(
      tester,
      size: size,
      state: loadedPresetState.copyWith(isCloneMode: moduleId == 9),
      selectedEffects: {...fullPresetEffects, moduleId: fxId},
      parameters: const {},
      overrides: [
        if (isCfw) ...[
          cfwInfoProvider.overrideWith((_) => cfw),
          currentSceneProvider.overrideWith((_) => isSc1 ? 1 : 0),
          sceneRecordsProvider.overrideWith(
            (_) => {
              if (isSc1) physId: SceneRecord(module: physId, sc1On: true),
            },
          ),
          expAssignsProvider.overrideWith(
            (_) => [
              if (isSc1 && knob != null)
                ExpAssign(module: physId, algId: knob.algId)
              else
                null,
              null,
              null,
              null,
            ],
          ),
          expKnownProvider.overrideWith((_) => true),
        ],
      ],
    );

    c.read(selectedModuleProvider.notifier).state = moduleId;
    await tester.pump();
  }

  bool inside(Rect r) =>
      (Offset.zero & size).contains(r.topLeft) &&
      (Offset.zero & size).contains(r.bottomRight - const Offset(0.01, 0.01));

  // The vertical scroll extent of the page around the editor, and of the
  // panel (and anything else) inside it.
  ({double page, double panel}) extents(WidgetTester tester) {
    final editor = find.byType(ModuleEditor);
    double most(Finder f) => tester
        .stateList<ScrollableState>(f)
        .where((s) => s.position.axis == .vertical)
        .fold(
          0.0,
          (m, s) =>
              s.position.maxScrollExtent > m ? s.position.maxScrollExtent : m,
        );

    return (
      page: most(find.ancestor(of: editor, matching: find.byType(Scrollable))),
      panel: most(
        find.descendant(of: editor, matching: find.byType(Scrollable)),
      ),
    );
  }

  final byModule = <int, List<int>>{};

  for (final id in assets.effects.effects.keys) {
    byModule.putIfAbsent(id ~/ 100, () => []).add(id);
  }

  for (final mode in modes) {
    for (final MapEntry(key: moduleId, value: ids) in byModule.entries) {
      if (moduleId > 9) continue;

      testWidgets('$mode: every effect of module $moduleId fits', (
        tester,
      ) async {
        for (final fxId in ids) {
          await pumpEffect(tester, mode, moduleId, fxId);

          final why = '$mode, effect $fxId';
          final e = extents(tester);

          expect(find.byType(BlockPanel), findsOneWidget, reason: why);
          expect(e.page, 0, reason: why);
          expect(
            inside(
              tester.getRect(
                find.descendant(
                  of: find.byType(ModuleEditor),
                  matching: find.byType(GearPiece),
                ),
              ),
            ),
            isTrue,
            reason: why,
          );
          // (An effect with no knob on its piece has no value line.)
          for (final line in tester.widgetList(
            find.byKey(const Key('piece-value')),
          )) {
            expect(inside(tester.getRect(find.byWidget(line))), isTrue);
          }
          if (mode == 'stock') expect(e.panel, 0, reason: why);
          // The prototype's 14-px padding and 16-px rows leave the CFW's
          // extra rows (scenes, EXP) a little short beside the heaviest
          // effects (cab bands, DLY tap tempo): the panel scrolls a bit.
          if (mode == 'CFW base') {
            expect(e.panel, lessThanOrEqualTo(64), reason: why);
          }
          expect(tester.takeException(), isNull, reason: why);

          // Cancels DLY's beat timer before the next pump.
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
