import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/ui/device_dialog.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';

void main() {
  testWidgets('device picker over the main screen, 1180x820', (tester) async {
    await pumpPage(tester, size: const Size(1180, 820), isConnected: false);
    await tester.pumpAndSettle();

    unawaited(
      showSonicDialog<String>(
        context: tester.element(find.byType(PresetBrowserPage)),
        builder: (_) => DeviceDialog(
          scanner: (_) async => const [
            DeviceEntry(
              name: 'Sonic Master BLE',
              subtitle: 'Pocket Master',
              isEnabled: true,
            ),
            DeviceEntry(name: '', subtitle: 'BLE', isEnabled: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BLUETOOTH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonic Master BLE'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('goldens/device_dialog_1180x820.png'),
    );
  });
}
