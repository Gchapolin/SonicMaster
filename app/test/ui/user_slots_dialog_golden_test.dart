import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/user_slots_dialog.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in const [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
      ('JetBrains Mono', 'JetBrainsMono'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file.ttf'))).load();
    }
  });
  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  testWidgets('slots dialog over the main screen, 1180x820', (tester) async {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    await pumpPage(
      tester,
      size: const Size(1180, 820),
      overrides: [
        cfwInfoProvider.overrideWith((_) => cfw),
        userNamesProvider.overrideWith(
          (_) => const {416: 'Jazz 2x12', 426: 'Last IR', 901: 'Satan 50'},
        ),
      ],
    );

    unawaited(
      showSonicDialog<void>(
        context: tester.element(find.byType(PresetBrowserPage)),
        builder: (_) => const UserSlotsDialog(),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/user_slots_dialog_1180x820.png'),
    );
  });
}
