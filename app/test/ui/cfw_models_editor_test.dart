import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

void main() {
  testWidgets('a CFW delay shows its knobs with the data\'s texts', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(820, 1180),
      selectedEffects: const {7: 751}, // Studio Delay
      parameters: const {
        7: {0: 30, 1: 500, 2: 35, 3: 1, 4: 100, 5: 0, 6: 0, 7: 1},
      },
      overrides: [
        selectedModuleProvider.overrideWith((_) => 7),
        cfwInfoProvider.overrideWith(
          (_) => decodeCfwSettingsFrame(cfwSettingsOriginal),
        ),
      ],
    );

    expect(find.text('Studio Delay'), findsWidgets);
    expect(find.text('21Hz'), findsOneWidget); // Low Cut = 1
    expect(find.text('500ms'), findsOneWidget);
    expect(find.text('TRAILS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a CFW delay synced through Trails shows a note division', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(820, 1180),
      selectedEffects: const {7: 751},
      parameters: const {
        7: {0: 60, 1: 4, 2: 74, 3: 0, 4: 39, 5: 0, 6: 0, 7: 3}, // Both
      },
      overrides: [
        selectedModuleProvider.overrideWith((_) => 7),
        cfwInfoProvider.overrideWith(
          (_) => decodeCfwSettingsFrame(cfwSettingsOriginal),
        ),
      ],
    );

    expect(find.text('1/4'), findsOneWidget); // Time 4
    expect(find.text('Both'), findsOneWidget);
  });

  test('the import knows as many divisions as the editor shows', () {
    expect(syncDivisionCount, syncDivisions.length);
  });
}
