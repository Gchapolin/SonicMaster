import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/user_ir_actions.dart';
import 'package:sonicmaster/ui/user_profile_actions.dart';
import 'package:sonicmaster/ui/user_slots_dialog.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';

void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<void> pump(
    WidgetTester tester, {
    bool isCfw = true,
    bool isConnected = true,
  }) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSonicHost(
      tester,
      home: const UserSlotsDialog(),
      overrides: [
        dataAssetsProvider.overrideWith((_) async => assets),
        connectionStateProvider.overrideWith((_) => isConnected),
        cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
        userNamesProvider.overrideWith(
          (_) => const {416: 'Jazz 2x12', 426: 'Last IR', 901: 'Satan 50'},
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CFW: ten IR and ten Clone slots, with their names', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(UserIrActions), findsNWidgets(10));
    expect(find.byType(UserProfileActions), findsNWidgets(10));
    expect(find.text('IR 1 · Jazz 2x12'), findsOneWidget);
    expect(find.text('IR 10 · Last IR'), findsOneWidget);
    expect(find.text('Clone 1 · Satan 50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock firmware: five of each', (tester) async {
    await pump(tester, isCfw: false);

    expect(find.byType(UserIrActions), findsNWidgets(5));
    expect(find.byType(UserProfileActions), findsNWidgets(5));
  });

  testWidgets('disconnected: the slot buttons are off', (tester) async {
    await pump(tester, isConnected: false);

    final load = tester.widget<SonicButton>(
      find
          .descendant(
            of: find.byType(UserIrActions).first,
            matching: find.byType(SonicButton),
          )
          .first,
    );

    expect(load.onPressed, isNull);
  });

  // The IR and Clone modules open the dialog, whatever cab or amp the preset
  // uses: no need to switch it to a user slot first.
  for (final (name, module, fx) in const [('IR', 4, 401), ('Clone', 9, 901)]) {
    testWidgets('the $name module opens the slots dialog', (tester) async {
      await pumpPage(
        tester,
        size: const Size(820, 1180),
        selectedEffects: {module: fx},
        parameters: const {},
        overrides: [selectedModuleProvider.overrideWith((_) => module)],
      );

      final button = find.text('Slots…');

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UserSlotsDialog), findsOneWidget);
    });
  }
}
