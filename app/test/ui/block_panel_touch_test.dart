import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/block_panel.dart';
import 'package:sonicmaster/ui/exp_controls.dart';
import 'package:sonicmaster/ui/scene_controls.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/test_assets.dart';
import '../support/text_fit.dart';

/// The CFW rows of the block panel (Scenes, EXP) and its switch pairs, at the
/// iPad's 1180x820: every control is a 44pt touch target, its text is whole and
/// its segment labels share one size.
void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<void> pumpEffect(WidgetTester tester, int moduleId, int fxId) async {
    final knobs = assets.effects
        .byId(fxId)!
        .paramsFor(isCfw: true)
        .where((p) => p.widgetType == .knob)
        .toList();

    // The knob with the longest name: the widest target label.
    knobs.sort((a, b) => b.name.length.compareTo(a.name.length));

    final c = await pumpPage(
      tester,
      size: const Size(1180, 820),
      selectedEffects: {...fullPresetEffects, moduleId: fxId},
      parameters: const {},
      overrides: [
        cfwInfoProvider.overrideWith((_) => cfw),
        currentSceneProvider.overrideWith((_) => 1),
        sceneRecordsProvider.overrideWith(
          (_) => {moduleId: SceneRecord(module: moduleId, sc1On: true)},
        ),
        expAssignsProvider.overrideWith(
          (_) => [
            if (knobs.isNotEmpty)
              ExpAssign(module: moduleId, algId: knobs.first.algId, max: 100)
            else
              null,
            null,
            null,
            null,
          ],
        ),
        expKnownProvider.overrideWith((_) => true),
      ],
    );

    c.read(selectedModuleProvider.notifier).state = moduleId;
    await tester.pump();
  }

  Finder inPanel(Finder f) =>
      find.descendant(of: find.byType(BlockPanel), matching: f);

  final byModule = <int, List<int>>{};

  for (final id in assets.effects.effects.keys) {
    byModule.putIfAbsent(id ~/ 100, () => []).add(id);
  }

  for (final MapEntry(key: moduleId, value: ids) in byModule.entries) {
    if (moduleId > 8) continue;

    testWidgets('module $moduleId: the scene and EXP rows are whole, 44pt and '
        'one size', (tester) async {
      for (final fxId in ids) {
        await pumpEffect(tester, moduleId, fxId);

        final why = 'effect $fxId';

        // BUG-31: no EXP target / range dropdown is cut.
        expectDropdownsNotTruncated(tester, find.byType(ExpControls));

        // BUG-34: touch targets.
        for (final f in [
          find.descendant(
            of: find.byType(SceneControls),
            matching: find.byType(SonicToggle),
          ),
          find.descendant(
            of: find.byType(SceneControls),
            matching: find.byType(SonicSegmented<int>),
          ),
          find.descendant(
            of: find.byType(ExpControls),
            matching: find.byType(SonicDropdown<int>),
          ),
        ]) {
          expect(f, findsWidgets, reason: why);

          for (final e in f.evaluate()) {
            expect(
              tester.getSize(find.byWidget(e.widget)).height,
              greaterThanOrEqualTo(44),
              reason: '$why ${e.widget.runtimeType}',
            );
          }
        }

        // BUG-34: Base is not drawn smaller than SC1 / SC2.
        for (final box
            in find
                .descendant(
                  of: find.byType(SceneControls),
                  matching: find.byType(FittedBox),
                )
                .evaluate()) {
          final text = find.descendant(
            of: find.byWidget(box.widget),
            matching: find.byType(Text),
          );

          expect(
            tester.getSize(text).width,
            lessThanOrEqualTo(tester.getSize(find.byWidget(box.widget)).width),
            reason: '$why shrunk: ${tester.widget<Text>(text).data}',
          );
        }

        // BUG-32: the panel's own text (Trails / Freeze, ...) is whole.
        for (final t in inPanel(find.byType(Text)).evaluate()) {
          expectNoTruncatedText(tester, find.byWidget(t.widget));
        }

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
