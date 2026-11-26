import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/cfw_backup_section.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';

import '../../support/backup_fixtures.dart';
import '../../support/changed_backup.dart';
import '../../support/fake_cfw_pedal.dart';
import '../../support/page_harness.dart';
import '../../support/test_assets.dart';

/// The restore confirmation over the main screen (prototype N_Restaurar).
void main() {
  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  testWidgets('restore confirmation over the main screen', (tester) async {
    final pedal = FakeCfwPedal();
    final file = await tester.runAsync(
      () => changedBackup(pedal, withOrder: true),
    );

    await pumpPage(
      tester,
      size: const Size(1180, 820),
      isConnected: false,
      home: Stack(
        children: [
          const PresetBrowserPage(),
          // Invisible handle: only there to open the dialog.
          Positioned(
            left: 0,
            top: 0,
            width: 300,
            child: Opacity(opacity: 0, child: const CfwBackupSection()),
          ),
        ],
      ),
      overrides: [
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
        deviceServiceProvider.overrideWithValue(pedal),
        cfwInfoProvider.overrideWith((_) => testCfwInfo()),
        backupFilePickerProvider.overrideWithValue(() async => file),
      ],
    );

    await tester.tap(find.text('Restaurar…'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Restaurar este backup?'), findsOneWidget);
    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('restore_confirm_1180x820.png'),
    );
  });
}
