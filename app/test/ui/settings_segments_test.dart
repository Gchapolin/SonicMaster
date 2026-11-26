import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
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

/// BUG-54: no segment label in Ajustes may be scaled below its natural size.
void main() {
  final models = parseCfwEqModels(
    jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  tearDown(() => appLang = Lang.en);

  for (final lang in [Lang.pt, Lang.en]) {
    testWidgets('segment labels keep their size at 1180x820 (${lang.name})', (
      tester,
    ) async {
      appLang = lang;
      await pumpPage(
        tester,
        size: const Size(1180, 820),
        overrides: [
          cfwInfoProvider.overrideWith(
            (_) => decodeCfwSettingsFrame(
              cfwSettingsOriginal,
            )!.copyWithSetting(CfwInfo.midiMapKey, CfwInfo.customMap),
          ),
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
              expFsType: 2,
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final boxes = find.descendant(
        of: find.descendant(
          of: find.byType(GlobalSettingsDialog),
          matching: find.byType(SonicSegmented<int>),
        ),
        matching: find.byType(FittedBox),
      );
      expect(boxes, findsWidgets);

      for (final box in boxes.evaluate()) {
        final boxSize = tester.getSize(find.byWidget(box.widget));
        final text = find.descendant(
          of: find.byWidget(box.widget),
          matching: find.byType(Text),
        );
        final textSize = tester.getSize(text);

        expect(
          textSize.width,
          lessThanOrEqualTo(boxSize.width + 0.5),
          reason: 'shrunk: ${tester.widget<Text>(text).data}',
        );
      }
    });
  }
}
