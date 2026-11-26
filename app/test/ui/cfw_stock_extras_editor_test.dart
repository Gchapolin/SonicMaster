import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

void main() {
  Future<void> pumpAnalog(WidgetTester tester, {required bool isCfw}) =>
      pumpPage(
        tester,
        size: const Size(820, 1180),
        selectedEffects: const {7: 707}, // Analog
        parameters: const {
          7: {0: 30, 1: 400, 2: 40, 3: 0, 4: 0, 5: 0, 6: 0, 7: 1},
        },
        overrides: [
          selectedModuleProvider.overrideWith((_) => 7),
          cfwInfoProvider.overrideWith(
            (_) => isCfw ? decodeCfwSettingsFrame(cfwSettingsOriginal) : null,
          ),
        ],
      );

  testWidgets('a stock delay on the CFW shows Tone / Duck / Trails', (
    tester,
  ) async {
    await pumpAnalog(tester, isCfw: true);

    expect(find.text('TONE'), findsOneWidget);
    // Knob-type params live on the piece (tablet), with its value line.
    expect(find.byKey(const Key('piece-value')), findsOneWidget);
    expect(find.text('DUCK'), findsOneWidget);
    expect(find.text('TRAILS'), findsOneWidget);
    expect(find.text('TRAIL'), findsNothing); // the slot-4 toggle
    expect(tester.takeException(), isNull);
  });

  testWidgets('on stock firmware it looks as before', (tester) async {
    await pumpAnalog(tester, isCfw: false);

    expect(find.text('TRAIL'), findsOneWidget);
    expect(find.text('TONE'), findsNothing);
    expect(find.text('DUCK'), findsNothing);
    expect(find.text('TRAILS'), findsNothing);
  });
}
