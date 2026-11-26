import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/test_assets.dart';

void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  testWidgets('a panel that scrolls (CFW SC1 + EXP, a delay) shows its '
      'scrollbar', (tester) async {
    final fxId = assets.effects.effects.keys.firstWhere((id) => id ~/ 100 == 7);
    final knob = assets.effects
        .byId(fxId)!
        .paramsFor(isCfw: true)
        .firstWhere((p) => p.widgetType == .knob);
    final c = await pumpPage(
      tester,
      size: const Size(1180, 820),
      selectedEffects: {...fullPresetEffects, 7: fxId},
      parameters: const {},
      overrides: [
        cfwInfoProvider.overrideWith((_) => cfw),
        currentSceneProvider.overrideWith((_) => 1),
        sceneRecordsProvider.overrideWith(
          (_) => {7: SceneRecord(module: 7, sc1On: true)},
        ),
        expAssignsProvider.overrideWith(
          (_) => [ExpAssign(module: 7, algId: knob.algId), null, null, null],
        ),
        expKnownProvider.overrideWith((_) => true),
      ],
    );

    c.read(selectedModuleProvider.notifier).state = 7;
    await tester.pump();

    final editor = find.byType(ModuleEditor);
    final scrollbar = find.descendant(
      of: editor,
      matching: find.byType(RawScrollbar),
    );

    expect(scrollbar, findsOneWidget);
    expect(tester.widget<RawScrollbar>(scrollbar).thumbVisibility, isTrue);
  });
}
