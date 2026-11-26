import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/model/cfw_eq_models.dart';
import 'package:sonicmaster/model/cfw_global_eq.dart';
import 'package:sonicmaster/model/cfw_info.dart';
import 'package:sonicmaster/model/global_settings.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/global_settings_dialog.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

/// Ajustes over the main screen at the prototype's 1180x820 (N_Ajustes), in
/// Portuguese with the prototype's faces: the typical CFW state, which fits
/// with no scrolling, and the tallest one (Custom MIDI map + DualFS), which
/// scrolls.
void main() {
  final models = parseCfwEqModels(
    jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
        as Map<String, dynamic>,
  );

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

  for (final (name, cfw, expFsType) in [
    ('typical', decodeCfwSettingsFrame(cfwSettingsOriginal)!, 0),
    (
      'tallest',
      decodeCfwSettingsFrame(
        cfwSettingsOriginal,
      )!.copyWithSetting(CfwInfo.midiMapKey, CfwInfo.customMap),
      2,
    ),
  ]) {
    testWidgets('Ajustes over the main screen, $name CFW state', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(1180, 820),
        overrides: [
          cfwInfoProvider.overrideWith((_) => cfw),
          cfwEqModelsProvider.overrideWith((_) => models),
          globalEqProvider.overrideWith(
            (_) => const CfwGlobalEq(
              isOn: true,
              model: 0,
              slots: [4, 0, 0, 0, 0, 50, 7, 100],
            ),
          ),
          globalSettingsProvider.overrideWith(
            (_) => GlobalSettings(
              globalVolume: 50,
              inputLevel: 0,
              fxRecLevel: 0,
              monitorLevel: 0,
              btRecLevel: 0,
              expFsType: expFsType,
            ),
          ),
        ],
      );

      unawaited(
        showSonicDialog<void>(
          context: tester.element(find.byType(PresetBrowserPage)),
          builder: (_) => const GlobalSettingsDialog(),
        ),
      );
      // No pumpAndSettle: the connected page's heartbeat (see pumpPage).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(SonicMasterApp),
        matchesGoldenFile('goldens/global_settings_${name}_1180x820.png'),
      );
    });
  }
}
